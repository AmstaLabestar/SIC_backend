# Référence API — SIC

> Référence canonique de l'API REST + WebSocket du backend SIC.
> **Source de vérité interactive** : Swagger UI auto-généré (drf-spectacular) sur
> **`/api/docs/`** (schéma OpenAPI brut : `/api/schema/`). Ce document décrit les
> conventions et les endpoints clés ; en cas de doute sur un champ exact, le schéma
> OpenAPI fait foi.

---

## Conventions

- **Base URL** : `http://<host>:8000/api/` (⚠️ pas de `/v1`).
- **Auth** : `Authorization: Bearer <access_jwt>` (simplejwt).
- **Garde PIN** : les opérations sensibles exigent un `pin_token` valide (≤ 5 min),
  passé en header `X-PIN-TOKEN` (ou champ `pin_token`). Obtenu via `auth/pin/verify/`.
- **Format** : JSON, `snake_case`. Montants en **FCFA** (les décimales peuvent revenir
  en string). Dates **ISO 8601 UTC**.
- **Pagination** : format DRF standard `{ count, next, previous, results }`.
- **Opérateurs** : `ORANGE`, `MOOV`, `TELECEL`, `MTN` (numéros : Burkina +226 = 8
  chiffres, Côte d'Ivoire +225 = 10 chiffres ; validation par préfixe).
- **Erreurs** : `{ "error": "...", "message": "..." }`. Codes : 400 (validation),
  401 (auth/token), 403 (suspendu / plafond KYC / IP webhook), 404, 429 (throttle), 500.

---

## Authentification & compte

| Méthode | Endpoint | Rôle |
|---|---|---|
| POST | `auth/register/` | Inscription (role CLIENT/AGENT). Déclenche l'OTP email. |
| POST | `auth/otp/send/` | (Re)envoyer un code OTP email. |
| POST | `auth/login/` | Login par **téléphone + mot de passe** → JWT. Exige OTP si nouvel appareil. |
| POST | `auth/device/verify/` | Vérifier l'OTP d'un nouvel appareil (device binding). |
| POST | `auth/refresh/` | Rafraîchir l'access token. |
| POST | `auth/verify/` | Vérifier un JWT. |
| POST | `auth/logout/` | Révoquer le refresh token (blacklist). |
| POST | `auth/password/reset/request/` | Demander un reset mot de passe (OTP email). |
| POST | `auth/password/reset/confirm/` | Confirmer le reset (OTP + nouveau mot de passe). |
| GET  | `auth/profile/` | Profil de l'agent connecté (+ ses puces). |
| GET  | `auth/limits/` | Plafonds KYC du compte + reste disponible (jour/mois). |
| POST | `auth/kyc/submit/` | Soumettre des documents KYC (upgrade de palier). |
| POST | `auth/kyc/review/` | (Admin) Revue/validation KYC. |

### Exemple — `POST auth/login/`
```json
// requête
{ "phone_number": "+22670000001", "password": "secret", "device_id": "uuid" }
// réponse 200
{ "access": "eyJ...", "refresh": "eyJ...", "agent_id": "uuid",
  "kyc_status": "T1", "first_name": "John", "phone_number": "+22670000001",
  "has_pin": true }
// réponse 401 si nouvel appareil → OTP exigé (→ auth/device/verify/)
```

> Détails du modèle de sécurité (step-up, device binding, OTP) : [SECURITY.md](SECURITY.md).

---

## Code PIN

| Méthode | Endpoint | Rôle |
|---|---|---|
| POST | `auth/pin/setup/` | Définir/modifier le PIN (exige le mot de passe). Refuse les PIN triviaux. |
| POST | `auth/pin/verify/` | Vérifier le PIN → renvoie un `pin_token` (300 s). |

```json
// POST auth/pin/verify/  → 200
{ "message": "Code PIN vérifié.", "pin_token": "abc...", "expires_in": 300 }
```
Le `pin_token` est ensuite envoyé en header **`X-PIN-TOKEN`** sur chaque opération.
Lockout après 5 essais → 15 min.

---

## Biométrie

| Méthode | Endpoint | Rôle |
|---|---|---|
| POST | `auth/biometric/register/` | Enrôler un appareil (clé publique). |
| POST | `auth/biometric/login/` | Login par signature biométrique. |
| GET/DELETE | `auth/biometric/devices/` | Lister / révoquer les appareils de confiance. |

---

## Puces (SIM) — `puces/` (ViewSet)

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `puces/` | Lister les puces de l'agent (paginé). |
| POST | `puces/` | Ajouter une puce (`operator`, `phone_number`). |
| GET | `puces/{id}/` | Détail. |
| PUT/PATCH | `puces/{id}/` | Modifier (`phone_number`, `operator`, `is_active`). |
| DELETE | `puces/{id}/` | Supprimer. |
| POST | `puces/{id}/topup/` | **(Admin)** recharge incrémentale (`amount`). |
| POST | `puces/{id}/set_balance/` | **(Agent, PIN)** caler le solde absolu après recharge physique. |

```json
// POST puces/{id}/set_balance/   (header X-PIN-TOKEN requis)
{ "balance": 250000 }   // → { "message": "Solde mis à jour", "balance": "250000.00" }
```

---

## Alertes — `alerts/` (ViewSet)

Seuils d'alerte de solde bas, **un par puce** (créés automatiquement à la création
d'une puce, paramétrables par l'agent).

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `alerts/` | Lister les alertes (une par puce). |
| GET/PATCH | `alerts/{id}/` | Lire / modifier (`threshold`, `is_enabled`). |

---

## Transactions — `transactions/` (ViewSet)

| Méthode | Endpoint | Rôle | Garde |
|---|---|---|---|
| GET | `transactions/` | Historique paginé de l'agent. | JWT |
| GET | `transactions/{id}/` | Détail. | JWT |
| POST | `transactions/deposit/` | Dépôt compensé. | JWT + PIN + KYC + non suspendu |
| POST | `transactions/transfer/` | Transfert P2P (compensé). | JWT + PIN + KYC |
| POST | `transactions/withdraw/` | Retrait (pas de compensation). | JWT + PIN + KYC |
| POST | `transactions/conversion/` | Swap entre deux puces de l'agent. | JWT + PIN |
| POST | `transactions/webhook/` | **Webhook agrégateur** (public, signé HMAC). | HMAC + IP allowlist |

### `POST transactions/deposit/` (et `transfer/`, `withdraw/`)
```json
// requête  (header X-PIN-TOKEN requis si PIN configuré)
{ "amount": 10000, "target_operator": "ORANGE", "target_phone_number": "70000002" }
// réponse 201
{ "message": "Dépôt initié avec succès", "transaction_id": "uuid",
  "amount": "10000.00", "commission_sic": "100.00",
  "is_compensated": true, "status": "PENDING", "created_at": "..." }
```
> ⚠️ Modèle de revenu (lot C4) : **commission SIC unique** (`commission_sic`). Il n'y a
> **plus** de `agent_benefit` / `agent_rate` (doc historique périmée).

### `POST transactions/conversion/`
```json
{ "amount": 5000, "source_puce_id": "uuid", "target_puce_id": "uuid" }
```

### `POST transactions/webhook/` (agrégateur → SIC)
Public mais **durci** : allowlist IP (`WEBHOOK_IPS`), signature **HMAC** (header
`x-token`) selon le schéma de champs de l'agrégateur, **vérification du montant**
(`cpm_amount` vs montant réservé), traitement **idempotent**. Voir [PAYMENTS.md](PAYMENTS.md).

```json
{ "cpm_trans_id": "<cinetpay_ref>", "cpm_site_id": "...", "cpm_amount": "10000",
  "cpm_currency": "XOF", "cpm_payment_date": "...", "cpm_payment_status": "ACCEPTED" }
```

---

## Divers

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `commissions/` | Taux de commission SIC + montants min/max (option `?type=DEPOT…`). |
| GET | `health/` | Sonde de santé/readiness (load balancer, orchestrateur). |
| GET | `/api/docs/` | Swagger UI interactif. |
| GET | `/api/schema/` | Schéma OpenAPI brut. |
| GET | `/metrics` | Métriques Prometheus (à restreindre au réseau interne en prod). |

---

## WebSocket — temps réel

```
WSS  ws/notifications/?token=<access_jwt>
```

- Auth par le `token` en query (middleware Channels). Un groupe par agent (`agent_<id>`).
- **Événements serveur → client** : `tx.created`, `tx.completed`, `tx.failed`.
  Payload : `{ type, transaction_id, tx_type, status, amount }`.
- Heartbeat ping/pong.
- **Le client traite tout événement comme un simple signal de re-synchronisation** :
  il re-fetch via REST (source de vérité). Le payload n'est jamais autoritaire.

---

## Schémas de données (rappel)

Voir [ARCHITECTURE.md §4](ARCHITECTURE.md) pour le modèle complet. Champs renvoyés
principaux :

- **Puce** : `id, operator, phone_number, balance, is_active, created_at, updated_at`.
- **Transaction** : `id, type, status, target_operator, target_phone_number, amount,
  commission_sic, fee, is_compensated, compensation_details[], created_at, updated_at`.
- **CompensationDetail** : `id, puce_operator, puce_phone, amount_deducted, status,
  cinetpay_ref, created_at`.
