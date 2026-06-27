# Plan de test — SIC v1

> Stratégie de test complète du projet (backend Django `api/`+`core/`+`dashboard/`,
> app Flutter `sic_mobile/`). Objectif fintech : **exactitude des mouvements d'argent**,
> **sécurité**, **non-régression**. Daté 2026-06-15.

---

## 1. Principes (fintech)

1. **L'argent ne ment pas** : toute opération qui touche un solde / une commission / une
   compensation doit avoir un test qui vérifie les montants **au centime**.
2. **Idempotence & rejouabilité** : webhooks et opérations réseau testés contre les doublons.
3. **Sécurité par défaut** : chaque endpoint protégé a un test « non authentifié → 401/403 »
   et « PIN requis ». Aucune régression de palier d'auth.
4. **Pyramide** : beaucoup d'**unitaires** (rapides), des **intégration** (API/repo), peu d'**E2E**
   (chers mais critiques). On ne teste pas l'UI pixel par pixel, on teste les **parcours**.
5. **Tout test tourne en CI** (cf. `.github/workflows/`) et bloque le merge si rouge.

---

## 2. Inventaire actuel (point de départ)

| Couche | Backend (Django) | Frontend (Flutter) |
|---|---|---|
| **Total** | **94 tests / 22 classes** ✅ | **113 tests + 1 E2E pilote** ✅ |
| Unitaire (logique pure) | CommissionCalculator, TransactionValidator, LimitsEngine, pin_rules, Agent/Puce models | validators, fcfa_formatter, jwt_utils, operator_mapping, pin_rules, dio_failure |
| Service / moteur | CompensationEngine | usecases (dashboard, sim, alerts, balance_update) |
| Intégration API / repo | TransactionAPI, KycLimitsAPI, LoginByPhone, DeviceBinding, PasswordReset, PinStrength, KycSubmit, EmailOtp, PuceGlobalUniqueness | datasources/repos (biometric), notifiers, providers |
| Sécurité | SecurityTest (401, token invalide, agent suspendu) | app_lock, pin_token_header |
| Sérialisation / mapping | RegisterSerializer | model.fromJson (transaction, balance, agent_summary) |
| Vues admin | DashboardViewsTest | — |
| Widget / E2E | — | `widget_test` (1 : redirection login) |

---

## 3. Couches de test — cible

### 3.1 Tests unitaires (base de la pyramide)

**Backend — logique métier pure (sans DB si possible) :**
- ✅ `CommissionCalculator` : taux par type (DEPOT/RETRAIT/TRANSFERT/SWAP), `commission_sic`, net, arrondis.
- ✅ `TransactionValidator` : montant min/max, opérateur, numéro par opérateur (BF/CI).
- ✅ `LimitsEngine` : plafonds T0/T1/T2 (op / jour / mois), cumul, message d'upgrade.
- ✅ `pin_rules` : PIN triviaux refusés.
- 🔲 **À ajouter** : `CompensationEngine.calculate_plan` cas limites (1 puce exacte, cascade 3+ puces, solde pile-poil, puce inactive ignorée, montant 0/négatif).
- 🔲 **À ajouter** : barème `fee` client (quand défini en D0).

**Frontend — logique pure :**
- ✅ `validators`, `fcfa_formatter`, `jwt_utils`, `operator_mapping`, `pin_rules`, `dio_failure`.
- 🔲 **À ajouter** : `pin_rules.dart` parité avec le backend (mêmes PIN refusés).

### 3.2 Tests d'intégration (API ↔ DB ↔ services)

**Backend (APITestCase) :**
- ✅ Dépôt / retrait / conversion / **transfert** (201, validations, PIN requis).
- ✅ Login par téléphone, device binding (+OTP nouvel appareil), reset OTP, PIN strength, KYC submit.
- ✅ KYC limites (403 + message au plafond), unicité globale des puces.
- 🔲 **À ajouter** :
  - **Webhook CinetPay** : signature valide/invalide, **idempotence** (même notif 2× → 1 seul effet),
    statut COMPLETED/FAILED, transaction inconnue.
  - **CinetPay client (chemin réel)** : mocker `requests` (responses/httpretty) → succès, timeout,
    erreur HTTP, mapping opérateur. Aujourd'hui **seul le mock interne est exercé**.
  - **Décaissement / payout** (dès qu'il existe, D0).
  - **Logout** : refresh token bien blacklisté (re-use → 401).
  - **Throttling** : dépasser le quota login/opération → 429.
  - **KYC review (admin)** : approve monte le palier, reject pose le motif.
  - **Rollback / timeout** de transaction (`check_transaction_timeout`).

**Frontend (datasource/repo/provider avec fakes & overrides Riverpod) :**
- ✅ transactions notifier, pin_token header, dashboard provider, biometric repo, auth (register,
  reset, device binding, kyc, pin).
- 🔲 **À ajouter** : datasource transfer (en-tête X-PIN-TOKEN — déjà couvert deposit/withdraw/convert,
  étendre à transfer), `submitKyc` multipart, mapping d'erreurs réseau bout-en-bout.

### 3.3 Tests fonctionnels / widget (Flutter)

> Aujourd'hui **quasi absents** (1 seul `widget_test`). Priorité moyenne mais utile pour les
> écrans à logique conditionnelle.

- 🔲 **RegisterScreen** : le sélecteur Agent/Client affiche/masque le champ **code marchand** ;
  code marchand requis si Agent (validation de formulaire).
- 🔲 **Routage role-based** : un user `isClient` atterrit sur `ClientHomeScreen`, un `isAgent`
  sur `DashboardScreen` (test du builder `/dashboard`).
- 🔲 **MoneyOperationScreen** : libellés selon `MoneyOperationKind` (Dépôt/Retrait/Envoyer),
  feuille PIN déclenchée avant soumission.
- 🔲 **Garde de route** (redirect) : pas de PIN → `/pin-setup` ; verrouillé → `/lock` ;
  non connecté → `/login`. (Étendre `widget_test`.)
- 🔲 **ClientHomeScreen** : actions présentes, « Recharger » → snackbar bientôt, relance KYC si non vérifié.

### 3.4 Tests E2E (parcours complets)

> **Inexistants aujourd'hui** (validation manuelle sur device via `adb`). Cible : package
> **`integration_test`** Flutter (piloté sur émulateur/CI) + backend réel (sandbox).

Scénarios prioritaires (cf. §4).

### 3.5 Tests de sécurité (transverses)

- ✅ Endpoints protégés → 401 sans token ; token invalide → 401 ; agent suspendu → 403.
- ✅ PIN obligatoire par opération (X-PIN-TOKEN), lockout 5 essais, PIN triviaux refusés.
- 🔲 **À ajouter** :
  - **Anti SIM-swap** : login depuis un nouvel appareil → 403 + OTP exigé (device binding) —
    vérifier qu'on **n'émet pas** les tokens avant l'OTP.
  - **IDOR** : un agent ne peut pas lire/agir sur la transaction/puce d'un autre (déjà partiellement
    via `retrieve` 404 — formaliser).
  - **Webhook** : rejet signature invalide, pas d'effet de bord sur rejeu.
  - **Reset** : un OTP de reset ne sert qu'une fois ; révoque les sessions.
  - **Expiration** : token PIN expiré (>5 min) → 401 ; OTP expiré → refus.

### 3.6 Non-fonctionnel (léger en v1)

- 🔲 **Charge** légère sur la compensation (k transactions concurrentes → pas de double-débit) —
  test de concurrence sur `calculate_plan`/MAJ solde (verrou/atomicité).
- 🔲 **Migrations** : `makemigrations --check` (déjà en CI) ; test d'application des migrations à blanc.

---

## 4. Scénarios E2E (parcours bout-en-bout)

> À automatiser avec `integration_test` (front) contre un backend **sandbox** (DB éphémère +
> CinetPay sandbox). En attendant l'automatisation : **checklist de test manuel** sur device.

### Parcours AGENT
1. **Onboarding agent** : inscription (rôle Agent + code marchand) → OTP email → création PIN → login.
2. **Dépôt** : montant + opérateur + numéro → PIN → succès, solde/historique mis à jour.
3. **Retrait** : idem, vérifier commission affichée.
4. **Envoyer (P2P)** : vers un numéro tiers → PIN → succès.
5. **Conversion** : entre 2 puces de l'agent → PIN → soldes ajustés.
6. **Plafond KYC** : opération > plafond T0 → refus + message d'upgrade → soumettre KYC → palier monte.
7. **Sécurité** : logout → re-login plein ; nouvel appareil → challenge OTP ; biométrie on/off ;
   PIN faux 5× → lockout.

### Parcours CLIENT (dépend de D0)
8. **Onboarding client** : inscription (rôle Client, sans code marchand) → OTP → PIN → accueil client.
9. **Envoyer** Orange → ami Moov : saisie → **paiement CinetPay (collecte)** → **livraison (décaissement)**
   → confirmation + historique. *(Bloqué tant que D0 n'est pas branché.)*
10. **Recharge** crédit téléphonique via CinetPay.
11. **Reset mot de passe / PIN** par OTP email.

### Parcours fonds (critique — à automatiser en intégration)
12. **Webhook** : paiement initié → notif CinetPay → statut COMPLETED ; **rejouer la notif** → aucun double effet.
13. **Échec / timeout** : pas de confirmation → rollback, solde restitué.

---

## 5. Gaps prioritaires (ce qui manque le plus)

| Priorité | Gap | Couche | État |
|---|---|---|---|
| 🔴 P1 | Webhook compensation : **idempotence** (anti-rejeu) + **select_for_update** | Intégration backend | ✅ fait (2026-06-17, `CompensationWebhookTest` + fix `_process_success`) |
| 🔴 P1 | CinetPay client chemin **réel** (HTTP mocké) + **décaissement** + signature webhook | Intégration backend | ⏳ gated D0 |
| 🟠 P2 | `CompensationEngine.calculate_plan` cas limites | Unitaire backend | ✅ fait |
| 🟠 P2 | logout/blacklist, throttling 429, **OTP verrou anti brute-force** | Intégration backend | ✅ fait |
| 🟠 P2 | KYC review admin (approve/reject/non-admin) | Intégration backend | ✅ déjà couvert (KycSubmitTest) |
| 🟠 P2 | RegisterScreen Agent/Client + accueil client | Widget Flutter | ✅ fait (`register_role_test`, `client_home_test`) |
| 🟡 P3 | Routage `/dashboard` role-based (builder) | Widget/E2E | 🔲 reste (couvrir via E2E §4) |
| 🟡 P3 | E2E automatisés (`integration_test`) des parcours §4 | E2E | 🟡 socle + 1 pilote (boot→login) fait ; parcours §4 à écrire |
| 🟡 P3 | Widget/garde de route, ClientHomeScreen, MoneyOperationScreen | Widget Flutter | 🔲 reste |
| 🟡 P3 | Parité `pin_rules` front/back, datasource transfer | Unitaire | 🔲 reste |

---

## 6. Outillage & exécution

- **Backend** : `python manage.py test` (Django TestCase/APITestCase). Ajouter **coverage**
  (`coverage run manage.py test && coverage report`), viser **≥ 80 %** sur `api/services/` et `api/views.py`.
  Mocker l'HTTP CinetPay avec `responses` ou `requests-mock`.
- **Frontend** : `flutter test` (unit/widget) + `flutter test integration_test/` (E2E sur device/émulateur).
  `flutter test --coverage` → `coverage/lcov.info`.
- **CI** (déjà en place) : jobs Django (+Postgres) et Flutter (analyze+test). **À enrichir** :
  rapport de couverture, et un job `integration_test` sur émulateur Android (ex. `reactivecircus/android-emulator-runner`).
- **Données de test** : factories/fixtures isolées par classe (chaque `TestCase` = transaction
  rollback). ⚠️ Numéros de puce **uniques** (contrainte `Puce.phone_number`), `cache.clear()` en
  `setUp` des tests qui touchent au throttling.

---

## 7. Definition of Done (qualité de test v1 prod)

- [ ] Tous les **gaps P1** couverts (webhook idempotent, CinetPay réel + décaissement).
- [ ] Couverture **≥ 80 %** sur le cœur métier backend (`services/`, `views.py`).
- [ ] Au moins **les parcours E2E §4 (1–7)** automatisés ou cochés en checklist manuelle signée.
- [ ] CI verte (back + front) **bloquante** sur PR + rapport de couverture publié.
- [ ] Tests de sécurité §3.5 verts (SIM-swap, IDOR, webhook, expiration).
