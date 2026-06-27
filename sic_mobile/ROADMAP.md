# Feuille de route — Reste à faire

> Audit des specs **PHASE1.md / PHASE2.md / PHASE3.md** confronté au code réel
> (backend Django `api/` + `core/`, frontend Flutter `sic_mobile/lib/`).
> Objectif : savoir ce qui est **fait**, ce qui **manque**, et dans quel **ordre**
> implémenter le reste.
>
> Date de l'audit initial : 2026-06-12.

> ### 🔄 Mise à jour 2026-06-26 — lire d'abord
> Depuis l'audit, le **chantier CinetPay (D0) a beaucoup avancé** : le passage « non
> branché / argent ne bouge pas » du §8 est **périmé**. État réel :
> - **Paiement codé de bout en bout** (mode `mock` par défaut) : encaissement, décaissement
>   (`payout`), webhook durci (HMAC, montant, IP, idempotence), réconciliation. + **abstraction
>   `PaymentProvider`** (HUB2 enfichable, voir [../docs/PAYMENTS.md](../docs/PAYMENTS.md)).
> - **Infra prod ajoutée** : backups PostgreSQL, images Docker slim, métriques Prometheus/Grafana,
>   celery-beat, CI. **Sentry** intégré côté app.
> - Reliquats Phase 2 **B3 alertes backend** et **B4 MAJ solde** : **faits**.
> - **Temps réel WebSocket** : fait (non prévu dans l'audit initial).
>
> **Le bloqueur D0 a changé de nature** : il n'est plus dans le *code* mais dans
> l'*opérationnel* — obtenir le **compte marchand** + **valider en sandbox** (le payout réel
> et l'ordre des champs HMAC sont codés mais non testés contre l'API réelle). Doc système à
> jour : [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md). Le reste de ce document (sécurité,
> socle métier, plan §8) reste valide comme carte du « reste à faire ».

---

## 0. Décisions structurantes v1 — DÉCIDÉ (2026-06-13)

### 0.A — Plateforme à DEUX FACES (agent + client)

SIC v1 sert **deux publics** dans **une seule app role-based** :
- **CLIENT** (grand public) : accueil simple → *Transférer / Recharger / Historique*.
  **Overlay / pass-through** : ne stocke aucun fonds, paie à l'instant via **CinetPay**
  (déjà intégré), SIC livre cross-réseau. Le client paie des **frais**.
- **AGENT** (PDV) : dashboard actuel (float multi-SIM, compensation, commissions). Inchangé.
- **Socle commun** : sécurité (0.B), KYC paliers (0.C), rails transfert/recharge, historique.

> ⚠️ Le code actuel est **100 % agent-centré** (`Transaction`/`Puce`/`BiometricDevice` = FK
> `Agent`, `IsApprovedAgent` partout, aucun concept de client). C'est un **élargissement**.
> **Wallet à valeur stockée = reporté en v2** ; concevoir le grand livre **extensible dès v1**
> (propriétaire `Transaction` généralisé agent OU client, champ `fee`) → v2 = extension, pas réécriture.

### 0.C — KYC par paliers (tiered KYC)

Remplacer le **blocage dur** `IsApprovedAgent` par un **moteur de limites par palier**,
calculé **côté serveur**. Limites **cumulées** (par op + journalier + mensuel + solde max) —
un simple plafond par op est contournable par fractionnement.

| Palier | Vérification | Plafond par op (départ) |
|---|---|---|
| **T0 Starter** | email + tél. vérifiés | **200k FCFA** (paramétrable) |
| **T1 Vérifié** | pièce d'identité | élevé |
| **T2 Complet** | pièce + selfie/liveness + adresse | selon politique |

Seuils à **valider compliance/BCEAO**. Champs KYC déjà sur `Agent` (`id_card_*`, `selfie_url`,
`kyc_status`) ; manque le **flux de soumission**. S'applique aux 2 rôles (agent starter ET client).

### 0.B — Modèle de sécurité (step-up auth)

Approche fintech **par paliers (step-up auth)** : le niveau d'effort exigé dépend du
**risque du moment**, pas d'un empilement de facteurs partout. Validé avec l'utilisateur.

| Palier | Quand | Facteur exigé | État |
|---|---|---|---|
| **P0 — Onboarding** | inscription (une fois) | **OTP par EMAIL** + KYC | ❌ à construire |
| **P1 — Login plein** | logout / session expirée / **nouvel appareil** | **téléphone + mot de passe** (+ OTP email si nouvel appareil) | 🟡 login OK, identifiant à migrer |
| **P2 — Déverrouillage** | retour app, **session vivante** | **biométrie** (principal) → **PIN** (secours) | 🔵 PIN fait (E3) ; biométrie à câbler |
| **P3 — Autorisation d'opération** | chaque dépôt/retrait/transfert | **PIN** par transaction (`X-PIN-TOKEN`) | ✅ fait (E4) |

**Déclencheur clé** : login plein vs déverrouillage rapide dépend de la **validité de la
SESSION** (refresh token), pas du fait que l'app soit fermée. Session vivante → biométrie/PIN ;
logout / session morte / nouvel appareil → login plein.

**Couches transverses (sécurité fintech) :**
- **Device binding** ✅ décidé : session liée à l'appareil + **OTP email exigé sur tout nouvel
  appareil** → défense n°1 contre le **SIM-swap** (fraude mobile money n°1 en Afrique de l'Ouest).
  Plus protecteur qu'ajouter un facteur de plus.
- **Sessions révocables** (logout backend blackliste le refresh — déjà en place).
- **Anti-brute-force** : lockout PIN 5 essais → 15 min (déjà) ; **refuser les PIN triviaux**
  (0000 / 1234 / 1111 — à ajouter).
- **Reset** mot de passe / PIN via **OTP email**.

**Choix de canal OTP — assumé.** L'OTP par **email** prouve la possession de l'**email**, pas
du numéro. C'est un choix v1 (gratuit, aucune passerelle SMS à payer) : l'email = canal de
**vérification + récupération**, la validation réelle du numéro/identité = **KYC**. Le système
est conçu **canal-agnostique** → bascule **SMS / WhatsApp** plus tard sans refonte.

### Autres divergences (actées, on n'y revient pas)

| Spec d'origine | Réalité | Statut |
|---|---|---|
| OTP **SMS** | OTP **email** v1 (canal interchangeable) | ✅ tranché |
| Identifiant = téléphone | actuellement **username** → **à migrer vers téléphone** | 🟡 à faire |
| Compensation = **stepper manuel** côté app | compensation **automatique serveur** (`CompensationEngine`) | ✅ transparent |
| API `/api/v1/...` | API `/api/...` | ✅ acté |

---

## 1. Synthèse par phase

| Phase | Périmètre | État global |
|---|---|---|
| **Phase 1** — Auth | Splash, Onboarding, Inscription, OTP, Login, biométrie, refresh JWT | 🟡 **~70 %** (cœur fait via PIN ; manque onboarding, biométrie front, reset) |
| **Phase 2** — Dashboard & Puces | Thème, Dashboard, CRUD puces, MAJ solde, Alertes | 🟢 **~85 %** (manque persistance backend alertes + MAJ solde) |
| **Phase 3** — Opérations | Sélection, Dépôt, Retrait, Compensation, Transfert, Reçu | 🟡 **~65 %** (dépôt/retrait/transfert OK ; manque écran sélection, reçu PDF, recharge, visu compensation) |

Légende : ✅ fait · 🟡 partiel · ❌ manquant · 🔵 backend prêt / front manquant

---

## 2. Détail Phase 1 — Authentification

| Élément | Backend | Frontend | Statut |
|---|---|---|---|
| Splash + routing au démarrage | — | `splash_screen.dart` | ✅ |
| Onboarding (3 slides) | — | absent | ❌ |
| Inscription | `RegisterView` | `register_screen.dart` | ✅ (username/password) |
| Vérification **OTP email** (inscription) | absent | absent | ❌ à construire |
| Connexion (password) | `CustomTokenObtainPairView` | `login_screen.dart` | ✅ |
| Identifiant = **téléphone** (au lieu de username) | `USERNAME_FIELD` = username | login par username | 🟡 à migrer |
| Refresh JWT auto + secure storage | simplejwt | `auth_interceptor.dart`, `token_storage.dart` | ✅ |
| Logout (efface tokens, révoque refresh) | `LogoutView` | `auth_provider.dart` | ✅ |
| **PIN** : setup / verify / lock app / par-opération | `PinSetupView`, `PinVerifyView` | E1→E4 | ✅ |
| **Biométrie** (déverrouillage principal) | `BiometricRegister/Login/DeviceList` + pkg `local_auth` présent | **aucun code UI** | 🔵 |
| **Device binding** + OTP nouvel appareil | partiel (`BiometricDevice`) | absent | ❌ à construire |
| Mot de passe / PIN oublié → reset via OTP email | absent | absent | ❌ à construire |

**Manque réel Phase 1 (sécurité v1) :** OTP email à l'inscription · migration identifiant→téléphone ·
biométrie côté app · device binding + OTP nouvel appareil · reset via OTP · Onboarding (UX).

---

## 3. Détail Phase 2 — Dashboard & Gestion des puces

| Élément | Backend | Frontend | Statut |
|---|---|---|---|
| Thème SIC (couleurs, typo, spacing, radii, gradients, shadows) | — | `core/constants/*` | ✅ |
| Widgets & utils globaux (`sic_button`, `fcfa_formatter`, `validators`…) | — | `core/widgets`, `core/utils` | ✅ |
| Dashboard (soldes agrégés, bénéfices, hero, wallet SIM) | `AgentProfileView` + dashboard datasource | `dashboard_screen.dart` + widgets | ✅ (données réelles) |
| CRUD puces (ajouter / modifier / activer-désactiver / topup) | `PuceViewSet` (+ `topup`) | `sim_management/` + sheets | ✅ |
| Mise à jour solde manuelle | endpoint `puces/{id}/topup/` existe | feature `balance_update/` mais **datasource remote commentée** | 🟡 (local/non câblé) |
| Alertes solde (seuils par opérateur) | **aucun endpoint** | feature `alerts/` mais **datasource remote commentée** (Hive local) | 🟡 (local seulement) |

**Manque réel Phase 2 :** persistance **backend** des alertes (endpoint + câblage) · câblage backend de la **MAJ solde** (brancher sur `topup` ou nouvel endpoint).

---

## 4. Détail Phase 3 — Moteur d'opérations

| Élément | Backend | Frontend | Statut |
|---|---|---|---|
| Calcul commissions (1 % / part SIC) | `CommissionCalculator` + `/commissions/` | consommé dans les récaps | ✅ |
| Validation montant / numéro / opérateur | `TransactionValidator` | `validators.dart` | ✅ |
| Dépôt | `deposit` action | `money_operation_screen` (isDeposit) | ✅ + PIN |
| Retrait | `withdraw` action | `money_operation_screen` | ✅ + PIN |
| Transfert / conversion | `conversion` action | `transfer_screen` | ✅ + PIN |
| **Compensation inter-réseaux** | `CompensationEngine.calculate_plan` (auto, serveur) | **non visualisée** (l'API ne renvoie pas le plan détaillé) | 🟡 |
| Écran **sélection d'opération** (grille 2×2) | — | absent (`operations/` = stubs vides) ; accès direct depuis Dashboard | ❌ |
| **Recharge** crédit téléphonique (4ᵉ action) | absent | absent | ❌ |
| Confirmation succès | réponse transaction | `operation_success_sheet` (récap simple) | 🟡 |
| **Reçu PDF** + partage + QR | — | absent (pkg `pdf`/`printing` non installés) | ❌ |
| Historique des transactions | `TransactionViewSet` (list) | `transactions_screen.dart` | ✅ |
| Webhook statut (CinetPay) | `webhook` action + `cinetpay_client` | — (serveur) | ✅ |

**Manque réel Phase 3 :** écran de sélection d'opération · recharge · reçu PDF/partage · visualisation (lecture seule) du détail de compensation.

---

## 5. Feuille de route ordonnée

Quatre pistes : **A** Sécurité/Auth · **C** Socle métier & conformité · **D** Client grand
public · **B** Produit/agent. La séquence globale recommandée est en §6. Chaque lot est
livrable indépendamment (commit + push deux repos + merge), comme E1→E4.

> **Infra OTP email = colonne vertébrale.** Les lots A2, A4, A5 s'appuient tous sur un
> même socle : génération/envoi d'OTP email + vérification + throttling (modèle `OtpCode`,
> config SMTP). On le construit une fois dans A2, on le réutilise ensuite.

### Piste A — Sécurité / Authentification (priorité v1)

#### 🥇 A1 — Biométrie côté app · effort : moyen · *front seul*
- **Pourquoi d'abord** : backend **déjà prêt** (`BiometricRegister/Login/DeviceList`) +
  `local_auth` **déjà installé** → meilleur ratio valeur/effort, aucune dépendance.
- Enrôlement après login, déverrouillage biométrique de `lock_screen` (**principal**),
  PIN en **secours**. Palier P2 du §0.

#### 🥈 A2 — OTP email à l'inscription + socle OTP · effort : élevé · *backend + front*
- **Cœur de la sécurité v1.** Backend : modèle `OtpCode`, endpoints `otp/send` + `otp/verify`,
  envoi SMTP, **throttling** + expiration. Front : écran de saisie OTP (6 chiffres, timer,
  renvoi) inséré dans le flux d'inscription **avant** la création du PIN.
- Conçu **canal-agnostique** (email aujourd'hui, SMS/WhatsApp demain).

#### 🥉 A3 — Identifiant = téléphone · effort : moyen · *backend + front*
- Migrer `USERNAME_FIELD` / login pour accepter le **numéro** comme identifiant (le username
  reste interne). Front : champ « téléphone » au login. Palier P1.
- À faire tôt car ça touche le contrat de login (avant d'empiler device binding dessus).

#### A4 — Device binding + OTP sur nouvel appareil · effort : élevé · *backend + front* · **dépend de A2**
- **Anti SIM-swap.** Backend : enregistrer l'appareil (id + fingerprint), détecter un
  **nouvel appareil** au login → exiger un **OTP email** (réutilise A2) avant d'émettre les tokens.
  Liste/-révocation des appareils de confiance. Front : challenge OTP + écran « appareils ».

#### A5 — Reset mot de passe / PIN via OTP email · effort : moyen · *backend + front* · **dépend de A2**
- Endpoints `password-reset` / `pin-reset` déclenchés par **OTP email**. Front : « Mot de
  passe / PIN oublié ? » → OTP → nouveau secret. Ferme la boucle de récupération.

#### A6 — Durcissements · effort : faible
- Refus des **PIN triviaux** (0000/1234/1111), politique d'expiration de session explicite,
  re-auth périodique. Petits ajouts, gros gain de posture.

### Piste C — Socle métier & conformité (fonde le client + le KYC)

#### C1 — Rôles d'compte + propriétaire de transaction généralisé · effort : élevé · *backend + front* · **fondation**
- Introduire `account_type` (CLIENT | AGENT) ; généraliser le propriétaire de `Transaction`
  (aujourd'hui FK `Agent` obligatoire → initiateur agent **OU** client) + champ `fee` (client).
- Le float/puces/compensation/commission restent réservés au type AGENT.
- **Rien du côté client ne fonctionne sans ce lot** → à faire en premier de la chaîne client.

#### C2 — KYC par paliers + moteur de limites · effort : élevé · *backend + front* · **dépend de C1**
- Remplacer le blocage dur `IsApprovedAgent` par un **moteur de limites** (par op + journalier
  + mensuel + solde max), calculé serveur, par palier T0/T1/T2 (cf. §0.C).
- Débloque le besoin « opérer plafonné sans KYC » (agent starter ET client). Front : affichage
  du reste disponible + message d'upgrade au plafond.

#### C3 — Flux de soumission KYC (upgrade de palier) · effort : moyen · *backend + front*
- Capture/upload **pièce d'identité + selfie** (les champs existent déjà sur `Agent`), endpoint
  de soumission + revue. Front : écran KYC (T0→T1→T2). Réutilise l'upload pour les deux rôles.

### Piste D — Client grand public (dépend de C1 + overlay CinetPay)

#### D0 — Intégration CinetPay réelle (collect/payout + webhook) · effort : élevé · *backend* · **prérequis de D3/D4**
- **Quand** : juste avant la Piste D (le code n'a de valeur qu'avec un parcours client à encaisser).
  **Démarrer dès maintenant l'administratif** (compte marchand CinetPay + accès sandbox) : c'est
  le **délai externe long**, indépendant du code.
- **Déjà fait** : wrapper `api/services/cinetpay_client.py` (`initiate_payment` / `check_transaction`
  / `refund` / `verify_webhook_signature`) avec **mode simulation** (mock si credentials absents),
  endpoint `webhook` (`TransactionViewSet.webhook`), champs `cinetpay_ref` (`CompensationDetail`),
  `CINETPAY_CONFIG` (settings). ⚠️ L'appel réel est **commenté** dans `CompensationEngine`
  (`compensation_engine.py` ~L380) → aujourd'hui rien ne bouge réellement.
- **À faire** :
  - **Credentials réels** : `API_KEY`, `SITE_ID`, `SECRET_KEY`, `NOTIFY_URL`, `RETURN_URL`
    (sandbox d'abord, puis prod).
  - **Brancher** `initiate_payment` dans le flux selon le sens : **collect** (encaisser le client,
    cas D3/D4) vs **payout** (décaisser vers l'opérateur, compensation agent en prod).
  - **Webhook robuste** : vérif signature (déjà codée) + **idempotence** (rejouabilité CinetPay)
    + MAJ **atomique** du statut `Transaction`/`CompensationDetail` + **réconciliation**
    (`check_transaction` en filet de sécurité si le webhook se perd).
  - **NOTIFY_URL publique** : les webhooks ne tombent pas sur `localhost` (ngrok en dev, domaine en prod).
  - **Côté app** : gérer `return_url` / retour de paiement (deep link ou polling de statut).
  - **Tests sandbox** bout-en-bout avant prod.
- **Note agent vs client** : la **compensation agent** peut rester en mock tant qu'on est en
  pilote (float rechargé par admin) ; le **client (D3/D4) exige CinetPay réel** dès le départ
  (overlay = aucun solde interne à débiter).

#### D1 — Choix de rôle à l'inscription · effort : faible · *backend + front* · **dépend de C1**
- Sélecteur CLIENT/AGENT à l'inscription ; CLIENT = parcours par défaut, friction minimale.

#### D2 — Accueil & navigation client · effort : moyen · *front* · **dépend de C1, D1**
- Home client (solde indicatif/landing + Transférer/Recharger/Historique), routage role-based
  dans GoRouter (pas de dashboard agent ni multi-SIM pour le client).

#### D3 — Transfert client (overlay CinetPay) · effort : élevé · *backend + front* · **dépend de C1, C2**
- Le client initie un transfert cross-réseau, **payé via CinetPay** (collecte), SIC livre vers
  la destination. Pas de fonds stockés (overlay v1). Frais client + PIN par opération.

#### D4 — Recharge client (overlay) · effort : moyen · *backend + front* · **mutualisé avec B2**
- Achat de crédit téléphonique payé via CinetPay. **Même endpoint `recharge` que B2** (agent),
  différencié par rôle/frais.

### Piste B — Produit / Fonctionnel

#### B1 — Reçu d'opération (PDF + partage) (Phase 3) · effort : moyen · *front seul*
- Les 3 opérations marchent déjà ; le reçu **clôt la boucle** (preuve agent/client).
  Ajouter `pdf` + `printing`, générer depuis `OperationResult`, bouton Télécharger/Partager
  dans `operation_success_sheet`, QR de vérif (mock au début).

#### B2 — Écran sélection d'opération + Recharge (Phase 3) · effort : moyen · *backend + front*
- `operation_select_screen` (grille 2×2 Dépôt/Retrait/Transfert/Recharge) + route `/operations`.
- **Backend requis** : endpoint `recharge` (crédit téléphonique) calqué sur `deposit` (+ PIN).

#### B3 — Alertes : persistance backend (Phase 2) · effort : moyen · *backend + front*
- Seuils aujourd'hui **locaux** (Hive) → perdus au changement d'appareil. Backend : endpoints
  CRUD alertes (ou `alert_threshold` sur `Puce`). Front : câbler `alert_remote_datasource`.

#### B4 — Câblage backend MAJ solde (Phase 2) · effort : faible/moyen · *front surtout*
- `balance_update/` existe mais datasource remote **commentée** → brancher sur
  `puces/{id}/topup/` + invalider `dashboardNotifierProvider`.

#### B5 — Visualisation du détail de compensation (Phase 3) · effort : moyen · *backend + front*
- Compensation automatique mais **invisible** ; l'exposer (lecture seule) renforce la confiance.
  Backend : renvoyer le plan (`CompensationDetail`) avec le résultat. Front : section dépliable.
  ⚠️ Pas le stepper manuel de la spec (superflu vu la compensation serveur).

#### B6 — Onboarding (3 slides) (Phase 1) · effort : faible · *front seul*
- Confort de 1ʳᵉ ouverture. `onboarding_screen` (PageView + skip), flag persistant,
  liens « Commencer » → register / « J'ai un compte » → login.

---

## 6. Séquence globale recommandée

Ordre conseillé en 3 phases (les lots `(front)` peuvent avancer en parallèle des `(full)`).

```
PHASE 1 — Sécurité & socle (priorité v1 fintech)
  A1  Biométrie               (front)  ← gain rapide, indépendant, en // de tout
  C1  Rôles + Transaction généralisée  ← FONDATION du client
  C2  KYC paliers + moteur de limites  ← remplace le blocage dur, débloque "opérer plafonné"
  A2  OTP email + socle OTP            ← base de A4/A5 + vérif inscription
  A3  Identifiant = téléphone

PHASE 2 — Grand public (la nouvelle face)
  C3  Soumission KYC (upgrade T0→T1→T2)   ← rend C1/C2 exploitables, 100% interne
  D0  Intégration CinetPay réelle         ← prérequis D3/D4 (lancer l'admin compte marchand AVANT)
  D1  Choix de rôle à l'inscription
  D2  Accueil & navigation client
  D3  Transfert client (overlay CinetPay) ← dépend de D0
  D4  Recharge client          (= B2 mutualisé agent+client) ← dépend de D0

PHASE 3 — Durcissement & produit
  A4  Device binding (anti SIM-swap, dépend de A2)
  A5  Reset via OTP (dépend de A2)      A6  Durcissements (PIN triviaux…)
  B1  Reçu PDF        B5  Visu compensation     B3  Alertes backend
  B4  MAJ solde câblage                         B6  Onboarding (front)
```

Légende : (front) = pur Flutter · (full par défaut) = backend + frontend.
Dépendances dures : C1 → {D*, C2} · C2 → D3 · A2 → {A4, A5} · **D0 → {D3, D4}** · D4 = B2 (un seul endpoint recharge).

> **Avancement (2026-06-15)** : Phase 1 sécurité **bouclée** (A1–A6 ✅) ; socle métier
> C1✅ C2✅ C3✅ **C4✅** (correction modèle de revenu : commission SIC unique, dashboard =
> volume compensé) ; Piste D : **D1✅** (D1-1 inscription role-based + code marchand, D1-2
> navigation client) + envoi **P2P « Envoyer »** ✅ (swap renommé « Conversion »).
> **Reste pour la v1 prod : D0 (CinetPay réel) = bloc critique, puis durcissement prod
> (CI, fix tests, release) + reliquats produit.** Voir **§8** pour le plan de clôture.

---

## 8. Clôture v1 prod — audit, reste à faire, plan (2026-06-15)

### 8.1 Accompli (récap)

| Bloc | Lots | État |
|---|---|---|
| **Sécurité (Piste A)** | A1 biométrie · A2 OTP email · A3 login téléphone · A4 device binding (anti SIM-swap) · A5 reset OTP · A6 PIN durci | ✅ step-up auth complet |
| **Socle métier (Piste C)** | C1 types de compte · C2 KYC paliers + moteur de limites · C3 soumission KYC · C4 modèle de revenu corrigé | ✅ |
| **Client (Piste D)** | D1-1 inscription role-based + code marchand · D1-2 navigation client · envoi P2P « Envoyer » | ✅ |
| **Qualité** | Flutter **110 tests** + analyze propre · Django **83 tests** (75 ✅ / 8 dette) | 🟢 |

### 8.2 Audit — constats classés par sévérité

- ✅ **D0 CinetPay — CODÉ** (2026-06-26, mise à jour) : encaissement + décaissement
  (`payout`) + webhook durci + réconciliation, derrière `CINETPAY_MODE` (défaut `mock`)
  et l'abstraction `PaymentProvider`. ⚠️ **Mais non validé contre l'API réelle** : en mode
  `mock`, aucun argent ne bouge encore. **Le bloqueur v1 prod est désormais OPÉRATIONNEL** :
  obtenir le **compte marchand** (délai externe) + **valider en sandbox** (payout réel et
  ordre des champs HMAC codés mais non testés). Voir [../docs/PAYMENTS.md](../docs/PAYMENTS.md).
- ✅ **8 tests Django cassés — CORRIGÉ** (2026-06-15, collab `57ee72c`) : `CompensationEngineTest`
  (puces avec numéros distincts) + `DashboardViewsTest` (chemins admin `/login/` et `/`, le
  dashboard est monté à la racine). **Django 83/83 vert.**
- ✅ **CI — AJOUTÉE** (2026-06-15) : `.github/workflows/ci.yml` (collab : job Django + Postgres,
  job Flutter analyze/tests, garde anti-dérive de migrations) ; `sic_mobile/.github/workflows/flutter.yml`
  (perso : Flutter seul). Barrière de tests sur push/PR.
- 🟠 **Webhook à durcir pour D0** : **idempotence** (CinetPay rejoue les notifications) +
  **réconciliation** (`check_transaction` en filet si le webhook se perd) + MAJ atomique.
- 🟡 **`applicationId = com.example.myfirstapp`** — identifiant placeholder, à changer avant
  toute publication ; + signature de release, icône, splash.
- 🟡 **Barème `fee` client non défini** (commission prélevée au client) — à fixer avant D3.
- 🟡 **Pillow absent** → docs KYC en `FileField` (pas de validation/redimensionnement image
  serveur). Acceptable v1, à revoir prod.
- 🟡 **Reliquats produit Phase 2/3** : alertes (Hive local, pas backend), MAJ solde non câblée,
  reçu PDF, écran de sélection d'opération, recharge, visualisation compensation, onboarding.
- 🟢 **Posture sécurité backend solide** : gardes prod (SECRET_KEY, ALLOWED_HOSTS), HSTS,
  cookies secure/SameSite, CORS verrouillé, blacklist JWT au logout, throttling, `log_activity`.

### 8.3 Plan de clôture v1 prod (ordre fintech)

**Étape 1 — Rendre le client réel (cœur de valeur) — `D0` d'abord**
1. *(admin, en //)* Compte marchand **CinetPay** → `API_KEY`/`SITE_ID`/`SECRET_KEY` (sandbox puis prod) + `NOTIFY_URL` publique.
2. **D0** : brancher `initiate_payment` (sens **collect** client / **payout** agent), webhook **idempotent** + **réconciliation**, deep-link/poll de retour de paiement, tests sandbox bout-en-bout.
3. **D3** transfert client overlay (collect CinetPay) · **D4/B2** recharge airtime · **barème `fee` client**.

**Étape 2 — Durcissement prod & qualité**
4. ✅ ~~Corriger les **8 tests** cassés~~ (fait, 2026-06-15).
5. ✅ ~~**CI GitHub Actions**~~ (fait, 2026-06-15 — vérifier le 1ᵉʳ run vert sur GitHub).
6. **Release Android** : `applicationId` réel, keystore de signature, icône/splash, build `--release`.
7. **Secrets & observabilité** : `.env` prod hors-git, monitoring d'erreurs (Sentry), logs structurés.

**Étape 3 — Reliquats produit (confiance & complétude)**
8. **B1** reçu PDF · **B5** visualisation compensation · **B3** alertes backend · **B4** câblage MAJ solde · **B6** onboarding · **B2** écran sélection d'opération.

**Étape 4 — Conformité & go-live**
9. **Seuils KYC validés compliance/BCEAO** · CGU/Politique de confidentialité/rétention des données.
10. **Revue sécurité / pentest** · **pilote** avec agents réels (float rechargé par admin) avant ouverture client.

**Definition of Done v1 prod** : argent qui bouge réellement (D0 collect+payout, webhook idempotent) · client peut envoyer/recharger · CI verte · build release signé · seuils KYC validés · monitoring en place.

---

## 7. Notes pour l'implémentation

- **Conventions** : Clean Architecture (domain/data/presentation) + Riverpod + GoRouter
  + dartz `Either<Failure,T>` ; PIN obligatoire sur toute opération (`X-PIN-TOKEN`).
- **Garde-fous** : chaque lot doit finir avec `flutter analyze` propre + tests
  (≥ 1 par usecase/datasource) + build APK, puis commit/push **sur les deux repos**
  (collab + perso) — cf. workflow E1→E4.
- **Dépôt partagé** : `sic_mobile/` est suivi par deux repos git distincts → éviter les
  `checkout` croisés sur la même copie de travail (cf. incident merge E4).
- **Tests live** : valider sur device réel (PIN, biométrie, reçu) — non rejouable en CI.
