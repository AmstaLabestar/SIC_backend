# SIC Mobile

> Application mobile Flutter de la plateforme **SIC** (Système Inter-Connexion) —
> Mobile Money multi-opérateurs (Orange Money, Moov Money, Telecel, MTN) en Afrique de
> l'Ouest. App **role-based** : face **agent** (PDV) complète, face **client** (overlay) en cours.

Pour le contexte produit complet et le backend, voir le [README racine](../README.md) et
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

---

## Documentation (ce repo)

| Fichier | Contenu |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Clean Architecture, structure par feature, point de bascule unique. |
| [CONVENTIONS.md](CONVENTIONS.md) | Commits, nommage, style Dart, Riverpod, tests. |
| [ENVIRONMENT.md](ENVIRONMENT.md) | Installation et configuration de l'environnement de dev. |
| [BACKEND_CONTRACT.md](BACKEND_CONTRACT.md) | API consommée par l'app (réf. canonique : [../docs/API.md](../docs/API.md)). |
| [ROADMAP.md](ROADMAP.md) | Reste à faire, plan de clôture v1 prod. |
| [TEST_PLAN.md](TEST_PLAN.md) | Stratégie de test fintech. |

---

## Stack

| Domaine | Paquets |
|---|---|
| État | `flutter_riverpod` + `riverpod_generator` |
| Navigation | `go_router` (guards role-based) |
| Réseau | `dio` + `retrofit`, interceptor JWT (refresh auto) |
| Fonctionnel | `dartz` (`Either<Failure, T>`) · `equatable` |
| Temps réel | `web_socket_channel` (notifications de transaction en direct) |
| Stockage | `flutter_secure_storage` (tokens) · `hive_flutter` (cache local) |
| Sécurité | `local_auth` + `biometric_signature` · PIN |
| Médias / divers | `image_picker` (KYC) · `intl` · `uuid` · `flutter_dotenv` |
| Monitoring | `sentry_flutter` (actif si `SENTRY_DSN` défini dans `.env`) |
| Animations | `flutter_animate` |

> Police **Inter bundlée** (`assets/fonts/Inter.ttf`) — aucun fetch réseau runtime
> (démarrage instantané + hors-ligne). Pas de Firebase, pas de `google_fonts`, pas de
> `fl_chart` (retirés en optimisation perf).

---

## Démarrage rapide

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Riverpod / Retrofit / Hive

# Backend local (voir ../README.md) puis, device branché :
adb reverse tcp:8000 tcp:8000      # le device atteint le backend sur localhost:8000
flutter run                        # debug ; ou: flutter build apk

flutter analyze                    # doit être propre
flutter test                       # ~123 tests + 1 E2E pilote
```

Configuration via `.env` (non commité, voir [ENVIRONMENT.md](ENVIRONMENT.md)) :
`API_BASE_URL`, `WS_URL`, `SENTRY_DSN` (optionnel).

---

## Architecture en un coup d'œil

Clean Architecture **par feature** (domain / data / presentation), dépendances vers le
**domaine** uniquement. Le choix d'une source de données (remote / cache / mock) se fait
à **un seul endroit** : le provider Riverpod qui construit le repository (« point de
bascule unique »). Détails : [ARCHITECTURE.md](ARCHITECTURE.md).

```
lib/
├── core/         # thème, réseau (Dio + JWT), realtime, widgets/utils partagés
├── features/     # auth, dashboard, sim_management, balance_update, alerts,
│                 # transactions, stats, account, kyc…  (chacune en 3 couches)
└── main.dart     # entry point + cycle de vie temps réel
```

---

## Build release (rappel — à finaliser pour la prod)

⚠️ Avant publication : remplacer l'`applicationId` placeholder par un identifiant réel,
configurer un **keystore de signature**, vérifier icône/splash (`flutter_launcher_icons`
configuré sur `assets/icons/app_icon.jpeg`), puis `flutter build apk --release`. Voir
[ROADMAP.md](ROADMAP.md) §8.
