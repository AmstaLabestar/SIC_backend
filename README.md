# SIC — Système Inter-Connexion

> Plateforme Mobile Money multi-opérateurs pour l'Afrique de l'Ouest (Burkina Faso,
> Côte d'Ivoire). Backend Django + application mobile Flutter.

SIC interconnecte les opérateurs Mobile Money (Orange Money, Moov Money, Telecel, MTN).
Plateforme **à deux faces** dans une seule app role-based :

- **Agent (PDV)** — gère plusieurs comptes float (« puces »), effectue dépôts / retraits /
  transferts / conversions. Un **moteur de compensation** déduit automatiquement en
  cascade sur plusieurs puces quand une seule ne suffit pas.
- **Client (grand public)** — *overlay* : ne stocke aucun fonds, paie à l'instant via
  l'agrégateur, SIC livre cross-réseau.

---

## 📚 Documentation

| Document | Contenu |
|---|---|
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | **Commencer ici.** Architecture système de bout en bout, modèle de domaine, moteur de compensation, temps réel. |
| [docs/API.md](docs/API.md) | Référence API REST + WebSocket (Swagger interactif sur `/api/docs/`). |
| [docs/PAYMENTS.md](docs/PAYMENTS.md) | Agrégateur (CinetPay/HUB2), abstraction `PaymentProvider`, encaissement/décaissement, ce qui reste pour le réel. |
| [docs/SECURITY.md](docs/SECURITY.md) | Modèle d'auth par paliers (step-up), anti SIM-swap, KYC paliers. |
| [sic_mobile/README.md](sic_mobile/README.md) | Application mobile Flutter (architecture, setup, conventions). |
| [sic_mobile/ROADMAP.md](sic_mobile/ROADMAP.md) | Reste à faire, plan de clôture v1 prod. |
| [sic_mobile/TEST_PLAN.md](sic_mobile/TEST_PLAN.md) | Stratégie de test (fintech). |
| [ops/backup/README.md](ops/backup/README.md) · [ops/monitoring/README.md](ops/monitoring/README.md) | Sauvegardes PostgreSQL · monitoring Prometheus/Grafana. |

> 🤖 **Pour un agent IA ou un nouveau dev** : lire `docs/ARCHITECTURE.md` en premier
> (vue d'ensemble + liens), puis le domaine précis selon la tâche. Le code fait foi ;
> cette doc explique le *pourquoi* et les invariants (réservation des fonds, idempotence,
> step-up auth, point de bascule unique).

---

## 🏗️ Stack

**Backend** : Django + DRF · Channels (WebSocket, ASGI/daphne) · Celery + beat + Redis ·
PostgreSQL · JWT (simplejwt) · drf-spectacular (Swagger) · django-prometheus.

**Mobile** : Flutter 3 · Riverpod · go_router · Dio + Retrofit · dartz · web_socket_channel ·
flutter_secure_storage · local_auth/biometric_signature · sentry_flutter · Clean Architecture.

Détails et invariants : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 🚀 Démarrage rapide

### Backend

```bash
docker compose up -d                                   # web (daphne), celery, beat, postgres, redis
docker compose exec web python manage.py migrate
docker compose exec -T web python manage.py test       # 133 tests

# API interactive : http://localhost:8000/api/docs/    (Swagger)
# Métriques       : http://localhost:8000/metrics      (Prometheus)
```

Agent de démo (selon le seed) : `agent_demo` / `password123`. Les codes OTP s'affichent
dans les logs en dev : `docker compose logs -f web`.

### Mobile

```bash
cd sic_mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Riverpod / Retrofit / Hive
# Brancher un device puis :
adb reverse tcp:8000 tcp:8000                              # device → backend local
flutter run                                                # ou: flutter build apk
flutter analyze && flutter test
```

Setup détaillé : [sic_mobile/ENVIRONMENT.md](sic_mobile/ENVIRONMENT.md).

---

## 📦 Structure du dépôt

```
SIC/
├── api/            # DRF : vues, serializers, services (compensation, paiement, limites), realtime
├── core/           # modèles (Agent, Puce, Transaction, CompensationDetail), tâches Celery
├── config/         # settings, urls, asgi, celery
├── dashboard/      # back-office web Django
├── ops/            # sauvegardes PostgreSQL + monitoring
├── docs/           # documentation système (ce dossier)
├── sic_mobile/     # application Flutter (aussi suivie par un repo perso séparé)
└── docker-compose.yml
```

> **Dépôt double** : `sic_mobile/` est suivi par **deux** repos git (collab + perso).
> Éviter les `checkout` croisés sur la même copie de travail.

---

## 📊 État

**MVP avancé / pré-production (~80 %).** Côté agent complet, sécurité fintech,
intégration paiement codée (mode `mock` par défaut), infra prod en place (backups,
Docker slim, Prometheus, CI). **Reste pour la prod** : compte marchand agrégateur +
validation sandbox, durcissement release (applicationId, keystore), parcours client,
conformité (KYC/BCEAO), pilote. Détail : [sic_mobile/ROADMAP.md](sic_mobile/ROADMAP.md).

---

## 🤝 Conventions

Conventional Commits · Clean Architecture (mobile) · tests verts + analyze propre avant
commit. Voir [sic_mobile/CONVENTIONS.md](sic_mobile/CONVENTIONS.md).
