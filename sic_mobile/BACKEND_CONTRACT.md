# Contrat API Backend — Phase 2

> Ce document décrit ce que le frontend Flutter attend du backend Django.
> À partager avec le dev backend dès le début du projet.
> Le frontend utilise des mocks jusqu'à ce que ces endpoints soient disponibles.

**Base URL :** `http://[HOST]/api/v1`
**Auth :** Bearer JWT dans le header `Authorization`
**Format :** JSON, snake_case

---

## Authentification

### POST /auth/register/

Créer un nouvel agent.

**Request body :**
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "secure_password",
  "password_confirm": "secure_password",
  "phone_number": "+224621234567",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response 201 :**
```json
{
  "message": "Inscription réussie. Votre compte est en attente de validation KYC.",
  "user_id": "uuid",
  "phone_number": "+224621234567"
}
```

### POST /auth/login/

Authentifier un agent.

**Request body :**
```json
{
  "username": "john_doe",
  "password": "secure_password"
}
```

**Response 200 :**
```json
{
  "access": "eyJ...",
  "refresh": "eyJ...",
  "agent_id": "uuid",
  "kyc_status": "PENDING",
  "first_name": "John",
  "phone_number": "+224621234567",
  "has_pin": false
}
```

### POST /auth/refresh/

Rafraîchir le token d'accès.

**Request body :**
```json
{
  "refresh": "eyJ..."
}
```

### POST /auth/verify/

Vérifier un token JWT.

**Request body :**
```json
{
  "token": "eyJ..."
}
```

### POST /auth/logout/

Révoquer un refresh token.

**Request body :**
```json
{
  "refresh": "eyJ..."
}
```

### GET /auth/profile/

Récupérer le profil de l'agent connecté.

**Response 200 :**
```json
{
  "id": "uuid",
  "username": "john_doe",
  "email": "john@example.com",
  "phone_number": "+224621234567",
  "first_name": "John",
  "last_name": "Doe",
  "kyc_status": "APPROVED",
  "is_suspended": false,
  "puces": [
    {
      "id": "puce_uuid",
      "operator": "ORANGE",
      "phone_number": "0701234567",
      "balance": "250000.00",
      "is_active": true,
      "created_at": "2026-06-10T10:00:00Z",
      "updated_at": "2026-06-10T10:00:00Z"
    }
  ],
  "created_at": "2026-06-01T09:00:00Z",
  "updated_at": "2026-06-10T10:00:00Z"
}
```

---

## Code PIN

### POST /auth/pin/setup/

Configurer ou modifier le code PIN.

**Request body :**
```json
{
  "password": "secure_password",
  "pin": "1234",
  "pin_confirm": "1234"
}
```

### POST /auth/pin/verify/

Vérifier le PIN avant les actions sensibles.

**Request body :**
```json
{
  "pin": "1234"
}
```

**Response 200 :**
```json
{
  "message": "Code PIN vérifié.",
  "pin_token": "abc123...",
  "expires_in": 300
}
```

---

## Biométrie

### POST /auth/biometric/register/

Enregistrer un appareil biométrique.

**Request body :**
```json
{
  "device_id": "device-uuid",
  "device_name": "Samsung Galaxy A",
  "public_key": "-----BEGIN PUBLIC KEY..."
}
```

### POST /auth/biometric/login/

Se connecter avec biométrie.

**Request body :**
```json
{
  "device_id": "device-uuid",
  "signature": "hex_signature",
  "timestamp": 1717200000
}
```

**Response 200 :**
```json
{
  "message": "Authentification biométrique réussie.",
  "access": "eyJ...",
  "refresh": "eyJ...",
  "agent_id": "uuid",
  "first_name": "John"
}
```

### GET /auth/biometric/devices/

Liste les appareils biométriques enregistrés.

### DELETE /auth/biometric/devices/

Révoquer un appareil.

**Request body :**
```json
{
  "device_id": "device-uuid"
}
```

---

## Commission et santé

### GET /commissions/

Retourne les taux de commission et les limites.

**Query params optionnels**
- `type=DEPOT|RETRAIT|TRANSFERT|SWAP`

**Response 200 (tous types)** :
```json
{
  "commissions": {
    "DEPOT": { "sic_rate": 1.0, "agent_rate": 0.5 },
    "RETRAIT": { "sic_rate": 1.5, "agent_rate": 0.7 },
    "TRANSFERT": { "sic_rate": 1.2, "agent_rate": 0.6 },
    "SWAP": { "sic_rate": 1.0, "agent_rate": 0.5 }
  },
  "min_amount": 100,
  "max_amount": 5000000
}
```

**Response 200 (type spécifique)** :
```json
{
  "type": "DEPOT",
  "sic_rate": 1.0,
  "agent_rate": 0.5,
  "min_amount": 100,
  "max_amount": 5000000
}
```

### GET /health/

Point de santé de l'API.

**Response 200 :**
```json
{
  "status": "healthy",
  "timestamp": "2026-06-10T10:00:00Z",
  "version": "1.0.0"
}
```

---

## Puces (SIM)

### GET /puces/

Liste toutes les puces de l'agent. Réponse paginée.

**Response 200 :**
```json
{
  "count": 1,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": "uuid",
      "operator": "ORANGE",
      "phone_number": "0701234567",
      "balance": "250000.00",
      "is_active": true,
      "created_at": "2026-06-01T09:00:00Z",
      "updated_at": "2026-06-10T10:00:00Z"
    }
  ]
}
```

### POST /puces/

Ajouter une nouvelle puce.

**Request body :**
```json
{
  "operator": "MOOV",
  "phone_number": "0601234567"
}
```

### PUT/PATCH /puces/{id}/

Modifier une puce existante.

**Champs autorisés** : `phone_number`, `operator`, `balance`, `is_active`

### POST /puces/{id}/topup/

Recharger une puce (admin only).

**Request body :**
```json
{
  "amount": 50000
}
```

**Response 200 :**
```json
{
  "message": "Solde rechargé: 50000 FCFA",
  "new_balance": "300000.00"
}
```

---

## Transactions

### GET /transactions/

Liste paginée des transactions de l'agent.

### GET /transactions/{id}/

Détail d'une transaction.

### POST /transactions/deposit/

Créer un dépôt compensé.

**Request body :**
```json
{
  "amount": 10000,
  "target_operator": "ORANGE",
  "target_phone_number": "621234567"
}
```

**Response 201 :**
```json
{
  "message": "Dépôt initié avec succès",
  "transaction_id": "uuid",
  "amount": "10000.00",
  "commission_sic": "100.00",
  "agent_benefit": "50.00",
  "status": "PENDING",
  "created_at": "2026-06-10T10:00:00Z"
}
```

### POST /transactions/withdraw/

Créer un retrait.

**Request body :**
```json
{
  "amount": 10000,
  "target_operator": "ORANGE",
  "target_phone_number": "621234567"
}
```

### POST /transactions/conversion/

Convertir entre deux puces.

**Request body :**
```json
{
  "amount": 5000,
  "source_puce_id": "uuid-source",
  "target_puce_id": "uuid-target"
}
```

### POST /transactions/webhook/

Webhook public pour CinetPay.

**Headers**
- `x-token`: signature HMAC

**Request body**
```json
{
  "cpm_trans_id": "transaction_id",
  "cpm_site_id": "site_id",
  "cpm_amount": "10000",
  "cpm_currency": "XOF",
  "cpm_payment_date": "2024-01-01 12:00:00",
  "cpm_payment_status": "ACCEPTED"
}
```

**Response 200 :**
```json
{
  "success": true,
  "transaction_id": "uuid"
}
```

---

## Schémas de données clés

### Puce
- `id`
- `operator` (`ORANGE`, `MOOV`, `TELECEL`, `CORIS`)
- `phone_number`
- `balance`
- `is_active`
- `created_at`
- `updated_at`

### Transaction
- `id`
- `agent_name`
- `type` (`DEPOT`, `RETRAIT`, `TRANSFERT`, `SWAP`)
- `status` (`PENDING`, `COMPLETED`, `FAILED`)
- `target_operator`
- `target_phone_number`
- `amount`
- `commission_sic`
- `agent_benefit`
- `is_compensated`
- `compensation_details`
- `created_at`
- `updated_at`

### CompensationDetail
- `id`
- `puce_operator`
- `puce_phone`
- `amount_deducted`
- `status` (`PENDING`, `SUCCESS`, `REFUNDED`)
- `cinetpay_ref`
- `created_at`

---

## Codes d'erreur standard

| Code HTTP | Signification Flutter |
|---|---|
| 200 | Succès |
| 201 | Créé avec succès |
| 400 | Données invalides / validation |
| 401 | Authentification requise ou token invalide |
| 403 | Accès refusé / compte suspendu |
| 404 | Ressource introuvable |
| 500 | Erreur serveur |

**Format d'erreur standard (backend) :**
```json
{
  "error": "error_code_snake_case",
  "message": "Message lisible en français pour l'affichage"
}
```

---

## Notes importantes pour le dev backend

1. **Tous les montants en FCFA** — envoyer un nombre, les décimales peuvent être retournées sous forme de string.
2. **Toutes les dates en ISO 8601 UTC** — le frontend attend des dates normalisées.
3. **Pagination** — utiliser le format DRF standard `{ "count": N, "next": ..., "previous": ..., "results": [...] }`.
4. **Opérateurs supportés** — `ORANGE`, `MOOV`, `TELECEL`, `CORIS`.
5. **Vérifier le KYC** — les actions transactionnelles (`deposit`, `withdraw`, `conversion`) exigent un agent approuvé.
6. **CORS** — autoriser le frontend Flutter web/dev si nécessaire.
7. **JWT** — support standard simplejwt avec access/refresh ; login renvoie des claims utiles (`agent_id`, `kyc_status`, `first_name`, `phone_number`, `has_pin`).

