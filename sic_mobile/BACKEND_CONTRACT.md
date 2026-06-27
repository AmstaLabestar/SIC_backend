# Contrat API backend — vue mobile

> Ce que l'app Flutter consomme du backend Django. **Référence canonique et complète** :
> [../docs/API.md](../docs/API.md) (et le Swagger interactif sur `/api/docs/`). Ce
> document résume l'essentiel côté app ; en cas de divergence, `docs/API.md` + le schéma
> OpenAPI font foi.

---

## Conventions

- **Base URL** : `http://<host>:8000/api/` — ⚠️ **pas** de `/v1`.
- **Auth** : `Authorization: Bearer <access_jwt>` (simplejwt, refresh auto via interceptor).
- **Garde PIN** : opérations sensibles → header **`X-PIN-TOKEN`** (token signé, 300 s,
  obtenu via `auth/pin/verify/`).
- **Format** : JSON `snake_case`, montants FCFA, dates ISO 8601 UTC, pagination DRF
  (`count/next/previous/results`).
- **Opérateurs** : `ORANGE`, `MOOV`, `TELECEL`, `MTN`.
- **Erreurs** : `{ "error": "...", "message": "..." }` — 400/401/403/404/429/500.

---

## Authentification

- `POST auth/register/` — inscription (role CLIENT/AGENT) → déclenche l'OTP email.
- `POST auth/otp/send/` — (re)envoyer un OTP email.
- `POST auth/login/` — **login par téléphone + mot de passe** (⚠️ pas username).
  Renvoie `access`, `refresh`, `agent_id`, `kyc_status`, `first_name`, `phone_number`, `has_pin`.
  Exige un OTP si **nouvel appareil** → `auth/device/verify/`.
- `POST auth/device/verify/` — valider l'OTP d'un nouvel appareil (device binding anti SIM-swap).
- `POST auth/refresh/` · `POST auth/verify/` · `POST auth/logout/` (révoque le refresh).
- `POST auth/password/reset/request/` · `POST auth/password/reset/confirm/` — reset par OTP email.
- `GET auth/profile/` — profil agent + ses puces.
- `GET auth/limits/` — plafonds KYC + reste disponible (jour/mois).
- `POST auth/kyc/submit/` — soumettre documents KYC (upgrade de palier).

## PIN & biométrie

- `POST auth/pin/setup/` (exige mot de passe ; refuse PIN triviaux) · `POST auth/pin/verify/`
  (→ `pin_token`, `expires_in: 300`).
- `POST auth/biometric/register/` · `POST auth/biometric/login/` · `GET|DELETE auth/biometric/devices/`.

## Puces

- `GET/POST puces/` · `GET/PUT/PATCH/DELETE puces/{id}/`.
- `POST puces/{id}/set_balance/` — **(agent, PIN)** caler le solde absolu : `{ "balance": 250000 }`.
- `POST puces/{id}/topup/` — (admin) recharge incrémentale.

## Alertes

- `GET alerts/` · `GET/PATCH alerts/{id}/` — seuil par puce (`threshold`, `is_enabled`).

## Transactions

- `GET transactions/` · `GET transactions/{id}/`.
- `POST transactions/deposit/` · `transfer/` · `withdraw/` —
  `{ amount, target_operator, target_phone_number }` (+ `X-PIN-TOKEN`).
- `POST transactions/conversion/` — `{ amount, source_puce_id, target_puce_id }` (+ `X-PIN-TOKEN`).
- Réponse 201 : `{ transaction_id, amount, commission_sic, is_compensated, status, created_at }`.
  ⚠️ **Plus de `agent_benefit`** : modèle de revenu = **commission SIC unique** (`commission_sic`).
- `POST transactions/webhook/` — appelé par l'agrégateur (serveur↔serveur, signé HMAC), pas par l'app.

## Divers

- `GET commissions/` (taux + min/max) · `GET health/`.

---

## WebSocket temps réel

```
ws/notifications/?token=<access_jwt>
```
Événements `tx.created` / `tx.completed` / `tx.failed` →
`{ type, transaction_id, tx_type, status, amount }`. **L'app traite chaque événement
comme un signal de re-synchronisation** (re-fetch REST = source de vérité), jamais comme
une donnée autoritaire.

---

## Schémas renvoyés

- **Puce** : `id, operator, phone_number, balance, is_active, created_at, updated_at`.
- **Transaction** : `id, type (DEPOT/RETRAIT/TRANSFERT/SWAP), status (PENDING/COMPLETED/FAILED),
  target_operator, target_phone_number, amount, commission_sic, fee, is_compensated,
  compensation_details[], created_at, updated_at`.
- **CompensationDetail** : `id, puce_operator, puce_phone, amount_deducted,
  status (PENDING/SUCCESS/FAILED/REFUNDED), cinetpay_ref, created_at`.
