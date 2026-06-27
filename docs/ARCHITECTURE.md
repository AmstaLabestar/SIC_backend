# Architecture du système SIC

> Vue d'ensemble technique de bout en bout : backend Django + application mobile
> Flutter. Ce document est le point d'entrée pour comprendre **comment le système
> fonctionne réellement**. Pour les détails : [API.md](API.md), [PAYMENTS.md](PAYMENTS.md),
> [SECURITY.md](SECURITY.md), et l'architecture mobile dans [sic_mobile/ARCHITECTURE.md](../sic_mobile/ARCHITECTURE.md).

---

## 1. Qu'est-ce que SIC

**SIC (Système Inter-Connexion)** est une plateforme de Mobile Money pour l'Afrique
de l'Ouest (Burkina Faso, Côte d'Ivoire) qui interconnecte les opérateurs
(Orange Money, Moov Money, Telecel, MTN).

Plateforme **à deux faces**, dans **une seule app role-based** :

- **AGENT (PDV)** — gère plusieurs « puces » (comptes float Mobile Money, un par
  opérateur) depuis une interface unique. Effectue dépôts / retraits / transferts /
  conversions. Le **moteur de compensation** déduit automatiquement en cascade sur
  plusieurs puces quand une seule ne suffit pas. C'est le cœur historique, complet.
- **CLIENT (grand public)** — *overlay / pass-through* : ne stocke aucun fonds, paie
  à l'instant via l'agrégateur, SIC livre cross-réseau. Le client paie des frais.
  Le **wallet à valeur stockée est reporté en v2**.

SIC prélève une **commission unique** par transaction (modèle de revenu lot C4 :
pas de « part agent », le gain de l'agent vient du volume sauvé par la compensation).

---

## 2. Vue macro

```
┌──────────────────────────┐         HTTPS / WSS          ┌───────────────────────────────┐
│   App mobile Flutter      │ ───────────────────────────► │   Backend Django (daphne ASGI) │
│   (sic_mobile/)           │   REST (Dio) + WebSocket     │                                │
│                           │ ◄─────────────────────────── │   - DRF (API REST)             │
│   Clean Arch / Riverpod   │   notifications temps réel   │   - Channels (WebSocket)       │
└──────────────────────────┘                              │   - Celery + Beat (async)      │
                                                           └───────────────┬───────────────┘
                                                                           │
                        ┌──────────────────────────────────────┬──────────┴───────┬────────────────┐
                        ▼                                       ▼                  ▼                ▼
                ┌──────────────┐                        ┌──────────────┐   ┌──────────────┐  ┌──────────────┐
                │  PostgreSQL  │                        │    Redis     │   │  Agrégateur  │  │  Prometheus  │
                │ (vérité des  │                        │ (cache, file │   │ paiement     │  │  / Grafana   │
                │  soldes)     │                        │  Celery, WS) │   │ CinetPay/HUB2│  │ (métriques)  │
                └──────────────┘                        └──────────────┘   └──────────────┘  └──────────────┘
```

Le tout est orchestré par **docker-compose** : `web` (daphne sert HTTP **et** WS),
`celery`, `celery-beat`, `postgres`, `redis`, + monitoring.

---

## 3. Stack technique

### Backend (`api/`, `core/`, `config/`, `dashboard/`)

| Brique | Techno | Rôle |
|---|---|---|
| Framework | Django + Django REST Framework | API REST |
| Temps réel | **Django Channels** (ASGI, servi par **daphne**) | WebSocket notifications |
| Tâches async | **Celery** + **celery-beat** + Redis | timeout, réconciliation, purge OTP |
| Base de données | **PostgreSQL** | source de vérité (soldes, transactions) |
| Cache / broker / WS layer | **Redis** | cache, file Celery, channel layer |
| Auth | **simplejwt** (JWT access/refresh, blacklist au logout) | |
| Doc API | **drf-spectacular** | OpenAPI auto → Swagger UI `/api/docs/` |
| Observabilité | **django-prometheus** (`/metrics`) + Grafana | métriques |
| Paiement | wrapper agrégateur derrière `PaymentProvider` | CinetPay (HUB2 enfichable) |

### Mobile (`sic_mobile/`)

| Couche | Techno |
|---|---|
| UI | Flutter 3.x (Dart 3) |
| État | Riverpod (+ riverpod_generator) |
| Navigation | go_router (guards role-based) |
| Réseau | Dio + Retrofit, interceptor JWT (refresh auto) |
| Fonctionnel | dartz `Either<Failure, T>` |
| Temps réel | web_socket_channel |
| Stockage | flutter_secure_storage (tokens), Hive (cache local) |
| Sécurité | local_auth + biometric_signature, PIN |
| Monitoring | sentry_flutter (actif si `SENTRY_DSN`) |
| Police | **Inter** bundlée (pas de fetch runtime → démarrage instantané + offline) |

> ⚠️ Doc périmée fréquente : il n'y a **pas** de Firebase, **plus** de `google_fonts`
> ni `fl_chart` (retirés en optimisation perf). La police est bundlée.

---

## 4. Modèle de domaine (`core/models.py`)

```
User (Django) ──1:1── Agent ──1:N── Puce ──1:1── AlertConfig
                        │              │
                        │              └──1:N── CompensationDetail
                        │                          │
                        └──1:N── Transaction ──1:N─┘
                        │
                        └──1:N── BiometricDevice
```

| Modèle | Rôle | Champs clés |
|---|---|---|
| **Agent** | profil métier (lié à `User`) | `phone_number`, `kyc_status` (T0/T1/T2), `pin_code` (hashé), `is_suspended`, champs KYC (`id_card_*`, `selfie_url`) |
| **Puce** | un compte float réel chez un opérateur | `operator`, `phone_number` (**unique global**), `balance`, `is_active` |
| **AlertConfig** | seuil d'alerte solde bas (1 par puce) | `threshold`, `is_enabled` |
| **Transaction** | une opération | `type` (DEPOT/RETRAIT/TRANSFERT/SWAP), `status` (PENDING/COMPLETED/FAILED), `amount`, `commission_sic`, `fee` (client), `is_compensated` |
| **CompensationDetail** | une ligne de déduction sur une puce | `puce`, `amount_deducted`, `status` (PENDING/SUCCESS/FAILED/REFUNDED), `cinetpay_ref` (unique) |

**Le solde (`Puce.balance`) est une copie tenue par SIC**, pas une lecture directe
du float opérateur. Il est calé par l'agent (`set_balance`, gardé PIN) après une
recharge physique, puis maintenu automatiquement par le moteur. Voir §6.

---

## 5. Le moteur de compensation (`api/services/compensation_engine.py`)

C'est le **cœur métier**. Principe : **réservation des fonds à la création**.

### Création d'une opération compensée (dépôt / transfert)

1. **Validation** : montant, opérateur, numéro (`TransactionValidator`), plafonds
   KYC (`LimitsEngine`), agent non suspendu, PIN (`X-PIN-TOKEN`).
2. **Calcul du plan** (`calculate_plan`, **sous verrou** `select_for_update`) :
   puces actives triées par solde décroissant, déduction en cascade jusqu'à couvrir
   le montant. Si la **somme** des soldes < montant → « solde insuffisant ».
3. **Réservation** : pour chaque puce du plan, `balance -= montant` **immédiatement**,
   création d'un `CompensationDetail` (PENDING + `cinetpay_ref` unique).
4. **Transaction** créée en `PENDING`. Timeout planifié (`check_transaction_timeout`).
5. **Après commit** (`transaction.on_commit`, hors verrou) : règlement réel via
   l'agrégateur (`get_payment_provider().initiate_payment` par détail) **et**
   notification temps réel `tx.created`. En mode mock → aucun appel réseau.

### Règlement (webhook agrégateur)

`process_webhook(ref, status)` retrouve le `CompensationDetail` par `cinetpay_ref` :

| Statut | Effet (idempotent, sous verrou) |
|---|---|
| **SUCCESS** | détail → SUCCESS. **Pas de re-débit** (déjà réservé). Tous SUCCESS → tx `COMPLETED` (+ pour un SWAP, crédite la puce cible) + notif `tx.completed`. |
| **FAILED** | **recrédite** la puce, détail → FAILED, tx → FAILED + notif `tx.failed`. |
| **REFUNDED** | recrédite tout détail engagé, détail → REFUNDED. |

> **Pourquoi réserver à la création** : le solde affiché reflète immédiatement les
> fonds engagés ; le succès ne re-débite donc pas (sinon double comptage). Tout est
> **idempotent** (verrou de ligne + garde de statut) → un webhook rejoué n'a aucun effet.

### Cas particuliers

- **Retrait** : pas de compensation (`is_compensated=False`) — l'agent encaisse le cash.
- **Swap / Conversion** : débit réservé sur la puce source ; crédit de la cible **au règlement**.

### Filets de sécurité (`core/tasks.py`, Celery)

- `check_transaction_timeout` — planifié à la création ; rollback si encore PENDING au délai.
- `reconcile_stale_transactions` (celery-beat) — rattrape les PENDING périmées (tâche `eta`
  perdue, webhook manqué). En mode réel : interroge `check_transaction()` **avant** de
  rollbacker (ne jamais annuler un paiement abouti).
- `cleanup_expired_otps` — hygiène base.

---

## 6. Abstraction agrégateur de paiement

Le moteur ne dépend **jamais** d'un agrégateur concret, mais de l'interface
**`PaymentProvider`** (`api/services/payment_provider.py`) + d'un **point de bascule
unique** `get_payment_provider()` piloté par `settings.PAYMENT_PROVIDER` (défaut
`cinetpay`). Brancher HUB2 = écrire `Hub2Client(PaymentProvider)` + changer le réglage,
**sans toucher au moteur**. Détails complets : [PAYMENTS.md](PAYMENTS.md).

---

## 7. Temps réel (`api/realtime/`)

Fintech → l'agent doit voir une transaction changer de statut sans rafraîchir.

- **Transport** : WebSocket `ws/notifications/?token=<JWT>` (auth par middleware
  `JWTAuthMiddleware`), un groupe Channels par agent (`agent_<id>`), heartbeat ping/pong.
- **Émission** : `notify_agent(agent_id, payload)` appelé **après commit** par le moteur.
- **Principe clé** : le WebSocket **ne transporte jamais la vérité**. La base (REST)
  reste la source de vérité. À chaque événement/reconnexion, le client **re-synchronise**
  (re-fetch dashboard + transactions, débouncé 400 ms). Le payload sert de déclencheur,
  pas de donnée autoritaire.

---

## 8. Sécurité (step-up auth)

Approche par paliers (l'effort exigé dépend du risque du moment). Résumé :

| Palier | Quand | Facteur |
|---|---|---|
| P0 Onboarding | inscription | OTP email + KYC |
| P1 Login plein | logout / session morte / **nouvel appareil** | téléphone + mot de passe (+ OTP email si nouvel appareil) |
| P2 Déverrouillage | retour app, session vivante | biométrie → PIN (secours) |
| P3 Autorisation d'op. | chaque dépôt/retrait/transfert | **PIN** par transaction (`X-PIN-TOKEN`) |

Couches transverses : **device binding** (anti SIM-swap), sessions révocables (blacklist
JWT), lockout PIN, refus des PIN triviaux, reset par OTP, **KYC par paliers** (moteur de
limites `LimitsEngine` côté serveur). Détails complets : [SECURITY.md](SECURITY.md).

---

## 9. Arborescence du dépôt

```
SIC/
├── api/                      # DRF : vues, serializers, services métier
│   ├── views.py              # endpoints (auth, puces, transactions, webhook…)
│   ├── serializers.py
│   ├── urls.py
│   ├── services/
│   │   ├── compensation_engine.py   # ★ moteur (réservation, webhook, plan)
│   │   ├── payment_provider.py      # ★ interface PaymentProvider + factory
│   │   ├── cinetpay_client.py       # impl. CinetPay (encaissement/payout/webhook)
│   │   ├── limits.py                # moteur de plafonds KYC
│   │   ├── otp.py, pin_rules.py
│   └── realtime/             # Channels : middleware, consumers, notify, routing
├── core/                     # modèles, tâches Celery, admin, migrations
│   ├── models.py             # Agent, Puce, Transaction, CompensationDetail…
│   └── tasks.py              # timeout, réconciliation, purge OTP
├── config/                   # settings, urls, asgi, celery
├── dashboard/                # dashboard web Django (back-office)
├── ops/                      # backups PG + monitoring (voir ops/*/README.md)
├── docs/                     # ← cette documentation
├── sic_mobile/               # application Flutter (repo perso séparé aussi)
└── docker-compose.yml
```

---

## 10. Démarrage rapide

Voir [README.md](../README.md) (racine) pour le quickstart complet (docker backend +
flutter). En bref :

```bash
# Backend
docker compose up -d
docker compose exec web python manage.py migrate
docker compose exec -T web python manage.py test     # 133 tests

# API explorable : http://localhost:8000/api/docs/  (Swagger)
# Métriques      : http://localhost:8000/metrics
```

---

## 11. État du projet

MVP avancé / pré-production (~80 %). Le côté agent est complet, la sécurité de niveau
fintech, l'intégration paiement codée (mode `mock` par défaut), l'infra prod en place
(backups, Docker slim, Prometheus, CI). **Reste pour la prod** : compte marchand +
validation sandbox du paiement réel, durcissement release (applicationId, keystore),
parcours client, conformité (KYC/BCEAO), pilote. Plan détaillé : [../sic_mobile/ROADMAP.md](../sic_mobile/ROADMAP.md).
