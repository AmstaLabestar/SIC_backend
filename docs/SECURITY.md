# Sécurité — SIC

> Le modèle de sécurité fintech de SIC : authentification par paliers (step-up),
> défenses anti-fraude, KYC par paliers. Code : `api/views.py` (auth), `api/services/`
> (`limits.py`, `otp.py`, `pin_rules.py`), `core/models.py` (`Agent`, `BiometricDevice`).

---

## 1. Principe : step-up auth (effort proportionnel au risque)

On n'empile pas tous les facteurs partout. Le niveau d'effort exigé dépend du **risque
du moment** :

| Palier | Déclencheur | Facteur exigé | État |
|---|---|---|---|
| **P0 — Onboarding** | inscription (une fois) | **OTP email** + KYC | ✅ |
| **P1 — Login plein** | logout / session morte / **nouvel appareil** | **téléphone + mot de passe** (+ OTP email si nouvel appareil) | ✅ |
| **P2 — Déverrouillage** | retour app, **session vivante** | **biométrie** (principal) → **PIN** (secours) | ✅ |
| **P3 — Autorisation d'opération** | chaque dépôt / retrait / transfert / conversion | **PIN** par transaction (`X-PIN-TOKEN`) | ✅ |

**Déclencheur clé** : login plein vs déverrouillage rapide dépend de la **validité de la
session** (refresh token), pas du fait que l'app soit fermée. Session vivante →
biométrie/PIN ; session morte / nouvel appareil → login plein.

---

## 2. Identifiant = numéro de téléphone

Le login se fait par **téléphone + mot de passe** (le `username` Django reste interne).
C'est l'identité métier en Mobile Money.

---

## 3. OTP (socle canal-agnostique)

- **Canal v1 = email** (gratuit, aucune passerelle SMS à payer). L'OTP email prouve la
  possession de l'**email** ; la validation réelle du numéro/identité = **KYC**.
- Conçu **canal-agnostique** → bascule SMS / WhatsApp plus tard sans refonte.
- Usages : vérification à l'inscription, challenge **nouvel appareil**, reset mot de
  passe / PIN.
- **Throttling + expiration** ; purge des OTP expirés par Celery-beat (`cleanup_expired_otps`).
- En dev (`DEBUG`), les emails OTP s'affichent dans la console (`docker compose logs`).

---

## 4. PIN (autorisation d'opération — P3)

- `auth/pin/setup/` (exige le mot de passe) → PIN hashé sur l'`Agent`.
- `auth/pin/verify/` → renvoie un **`pin_token` signé** (Django signing, salt
  `pin-token`, **300 s**, lié à l'`agent_id`).
- Chaque opération sensible exige ce token en header **`X-PIN-TOKEN`** (revérifié côté
  serveur : signature, expiration, correspondance `agent_id`).
- **Anti-brute-force** : lockout après **5 essais** → 15 min.
- **Refus des PIN triviaux** (`0000`, `1234`, `1111`…) — `pin_rules.weak_pin_reason`.

---

## 5. Biométrie (déverrouillage — P2)

- Enrôlement après login (`auth/biometric/register/` avec une **clé publique**).
- Login par **signature** (`auth/biometric/login/`) — le device signe un challenge,
  le serveur vérifie avec la clé publique enregistrée.
- Liste / révocation des appareils : `auth/biometric/devices/`.
- Côté app : `local_auth` + `biometric_signature`.

---

## 6. Device binding (défense n°1 anti SIM-swap)

La fraude Mobile Money n°1 en Afrique de l'Ouest est le **SIM-swap**. Défense :

- La session est **liée à l'appareil** (id + fingerprint, modèle `BiometricDevice`).
- Au login, un **nouvel appareil** non reconnu → **OTP email exigé**
  (`auth/device/verify/`) **avant** d'émettre les tokens.
- Plus protecteur qu'ajouter un facteur de plus partout : un attaquant qui a fait un
  SIM-swap n'a toujours pas l'accès email ni un appareil de confiance.

---

## 7. KYC par paliers + moteur de limites

Le **blocage dur** historique (`IsApprovedAgent`) est remplacé par un **moteur de
limites** (`LimitsEngine`) calculé **côté serveur**, par palier :

| Palier | Vérification | Plafond par op (départ, paramétrable) |
|---|---|---|
| **T0 Starter** | email + tél. vérifiés | ~200 k FCFA |
| **T1 Vérifié** | pièce d'identité | élevé |
| **T2 Complet** | pièce + selfie/liveness + adresse | selon politique |

- Limites **cumulées** (par opération + journalier + mensuel + solde max) — un simple
  plafond par op est contournable par fractionnement.
- Vérifié à chaque opération (`deposit`/`transfer`/`withdraw`/`conversion`) → 403 +
  message d'upgrade si dépassé. Reste disponible exposé via `auth/limits/`.
- Soumission de documents : `auth/kyc/submit/` (upgrade T0→T1→T2), revue admin
  `auth/kyc/review/`.

> ⚠️ Les **seuils exacts doivent être validés compliance / BCEAO** avant le go-live.

---

## 8. Couches transverses

- **Sessions révocables** : `auth/logout/` blackliste le refresh token (simplejwt blacklist).
- **Throttling** DRF sur les endpoints sensibles (login, OTP…).
- **`log_activity`** : journal d'audit des actions sensibles (transactions, KYC, webhooks
  refusés, signatures invalides…).
- **Webhook agrégateur** : allowlist IP + signature HMAC + vérif montant + idempotence
  (cf. [PAYMENTS.md](PAYMENTS.md)).
- **Gardes prod backend** : `SECRET_KEY`/`ALLOWED_HOSTS` obligatoires hors debug, HSTS,
  cookies secure/SameSite, CORS verrouillé.

---

## 9. Reste pour la prod (sécurité)

- **Secrets prod** hors-git (`.env` prod, jamais commité).
- **Monitoring d'erreurs** : Sentry est intégré côté app (`sentry_flutter`, actif si
  `SENTRY_DSN`) ; prévoir l'équivalent backend.
- **Revue sécurité / pentest** avant ouverture au public.
- **Validation des seuils KYC** (compliance/BCEAO) + CGU / politique de confidentialité /
  rétention des données.
- Voir [../sic_mobile/ROADMAP.md](../sic_mobile/ROADMAP.md) §8 pour le plan de clôture.
