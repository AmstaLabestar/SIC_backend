# Architecture — SIC Mobile

## Principe fondamental

SIC Mobile suit la **Clean Architecture** de Robert C. Martin, adaptée à Flutter.
La règle d'or : **les dépendances ne vont que vers l'intérieur.**

```
Presentation  →  Domain  ←  Data
      ↓              ↑
   (UI, State)   (Métier pur)   (API, BDD)
```

- `Presentation` connaît `Domain`, jamais `Data`
- `Domain` ne connaît personne (pur Dart, zéro Flutter)
- `Data` implémente les interfaces de `Domain`

Changer une source de données ne touche que la couche `Data` (+ son provider). La UI et
le métier restent intacts.

> **État réel** : le backend Django **est branché** (REST + WebSocket temps réel). Les
> features consomment de vraies données via `dio` + interceptor JWT. Les exemples avec
> « mock » ci-dessous illustrent le pattern (et servent encore aux tests / au mode hors
> ligne), mais l'app tourne contre l'API réelle. Vue système : [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

---

## Structure des dossiers

```
lib/
├── core/                          # Partagé par toutes les features
│   ├── constants/
│   │   ├── app_colors.dart        # Palette SIC (couleurs fintech)
│   │   ├── app_text_styles.dart   # Typographie
│   │   ├── app_spacing.dart       # Marges et paddings
│   │   └── api_constants.dart     # URLs, timeouts
│   ├── errors/
│   │   ├── failures.dart          # Types d'échecs métier
│   │   └── exceptions.dart        # Exceptions techniques
│   ├── network/
│   │   ├── dio_client.dart        # Instance Dio configurée
│   │   ├── api_interceptor.dart   # JWT, refresh token
│   │   └── network_info.dart      # Vérification connectivité
│   ├── usecases/
│   │   └── usecase.dart           # Interface abstraite UseCase<T, P>
│   ├── utils/
│   │   ├── fcfa_formatter.dart    # Formatage montants FCFA
│   │   ├── date_formatter.dart    # Formatage dates FR
│   │   └── validators.dart        # Validation formulaires
│   └── widgets/                   # Widgets réutilisables globaux
│       ├── sic_button.dart
│       ├── sic_text_field.dart
│       ├── sic_loading.dart
│       └── sic_error_widget.dart
│
├── features/                      # Une feature = un écran ou groupe d'écrans
│   │                              # auth · dashboard · sim_management ·
│   │                              # balance_update · alerts · transactions ·
│   │                              # stats · account · kyc …
│   ├── dashboard/                 # Écran principal agent
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── dashboard_remote_datasource.dart
│   │   │   │   └── dashboard_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── agent_summary_model.dart
│   │   │   │   └── balance_summary_model.dart
│   │   │   └── repositories/
│   │   │       └── dashboard_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── agent_summary.dart
│   │   │   │   └── balance_summary.dart
│   │   │   ├── repositories/
│   │   │   │   └── dashboard_repository.dart   # Interface abstraite
│   │   │   └── usecases/
│   │   │       ├── get_dashboard_summary.dart
│   │   │       └── refresh_balances.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── dashboard_provider.dart
│   │       ├── screens/
│   │       │   └── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── balance_card.dart
│   │           ├── operator_chip.dart
│   │           ├── benefit_summary_widget.dart
│   │           └── quick_actions_row.dart
│   │
│   ├── sim_management/            # Gestion des puces (CRUD)
│   ├── balance_update/            # Mise à jour solde (set_balance, PIN)
│   ├── alerts/                    # Alertes solde bas (par puce)
│   ├── auth/                      # Auth : login, PIN, biométrie, OTP, KYC
│   └── transactions/             # Opérations + historique
│
├── core/realtime/                 # Client WebSocket (notifications transaction live)
└── main.dart                      # Entry point + cycle de vie temps réel
```

---

## Les 4 couches en détail

### 1. Domain (cœur métier — pur Dart)

C'est la couche la plus importante. Elle ne dépend de rien.

**Entities** — objets métier purs, sans annotation, sans JSON :
```dart
// features/dashboard/domain/entities/balance_summary.dart
class BalanceSummary {
  final String operatorName;
  final String operatorCode;   // 'OM', 'MOOV', 'TELECEL'
  final double balance;
  final bool isLow;            // true si < seuil configuré
  final DateTime lastUpdated;

  const BalanceSummary({ ... });
}
```

**Repository (interface)** — contrat que Data doit respecter :
```dart
// features/dashboard/domain/repositories/dashboard_repository.dart
abstract class DashboardRepository {
  Future<Either<Failure, AgentSummary>> getDashboardSummary();
  Future<Either<Failure, List<BalanceSummary>>> getBalances();
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode);
}
```

**UseCase** — une action métier = une classe :
```dart
// features/dashboard/domain/usecases/get_dashboard_summary.dart
class GetDashboardSummary implements UseCase<AgentSummary, NoParams> {
  final DashboardRepository repository;
  GetDashboardSummary(this.repository);

  @override
  Future<Either<Failure, AgentSummary>> call(NoParams params) {
    return repository.getDashboardSummary();
  }
}
```

---

### 2. Data (implémentation)

Implémente les interfaces du Domain. C'est la seule couche qui parle au réseau.

L'app consomme le **backend réel** via `*_remote_datasource.dart` (Dio + interceptor
JWT). Un datasource local (Hive) peut coexister pour le **cache** d'une donnée — mais une
donnée a **une seule source de vérité** (pas de cache qui duplique silencieusement le
serveur). Le branchement remote/local/mock se choisit dans **le provider** du repository.

```dart
class DashboardRemoteDatasource {
  DashboardRemoteDatasource(this._dio);
  final Dio _dio;

  Future<AgentSummaryModel> getDashboardSummary() async {
    final res = await _dio.get('/auth/profile/');     // backend réel
    return AgentSummaryModel.fromJson(res.data);
  }
}
```

**Models** = Entities + fromJson/toJson :
```dart
class BalanceSummaryModel extends BalanceSummary {
  factory BalanceSummaryModel.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}
```

---

### 3. Presentation (UI + State)

**Providers Riverpod** — état de l'écran :
```dart
// Toujours AsyncNotifier pour les données asynchrones
@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  @override
  Future<AgentSummary> build() => _load();

  Future<AgentSummary> _load() async {
    final usecase = ref.read(getDashboardSummaryProvider);
    final result = await usecase(NoParams());
    return result.fold(
      (failure) => throw failure,
      (summary) => summary,
    );
  }

  Future<void> refresh() => ref.refresh(dashboardNotifierProvider.future);
}
```

**Screens** — consomment les providers, délèguent aux widgets :
```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    return state.when(
      loading: () => const SicLoading(),
      error: (e, _) => SicErrorWidget(error: e),
      data: (summary) => _DashboardContent(summary: summary),
    );
  }
}
```

---

### 4. Core (partagé)

Tout ce qui est utilisé par plusieurs features :
- Thème visuel SIC (couleurs, typo, spacing)
- Client réseau Dio configuré
- Widgets communs (boutons, champs, états d'erreur)
- Utilitaires (formatage FCFA, dates, validation)

---

## Gestion des erreurs

Toutes les erreurs passent par `Either<Failure, T>` du package `dartz` :

```
Failure
├── ServerFailure        # Erreur HTTP (400, 500...)
├── NetworkFailure       # Pas de connexion
├── CacheFailure         # Erreur lecture locale
├── AuthFailure          # Token expiré, non autorisé
└── ValidationFailure    # Données invalides
```

La UI ne voit jamais d'exception brute — toujours un `Failure` typé.

---

## Principes SOLID appliqués

| Principe | Application dans SIC |
|---|---|
| **S** — Single Responsibility | 1 UseCase = 1 action. 1 Widget = 1 responsabilité. |
| **O** — Open/Closed | Ajouter un opérateur = ajouter un model, pas modifier l'existant |
| **L** — Liskov | Les Models étendent les Entities sans en briser le contrat |
| **I** — Interface Segregation | Repository séparé par feature, pas un Repository global |
| **D** — Dependency Inversion | Presentation dépend de l'interface Domain, jamais de Data |

---

## Injection de dépendances

On utilise **Riverpod** comme conteneur d'injection :

```dart
// Providers chaînés — Riverpod gère le cycle de vie
final dashboardDatasourceProvider = Provider((ref) =>
  DashboardRemoteDatasource(ref.read(dioProvider)));
final dashboardRepoProvider = Provider((ref) =>
  DashboardRepositoryImpl(ref.read(dashboardDatasourceProvider)));
final getDashboardSummaryProvider = Provider((ref) =>
  GetDashboardSummary(ref.read(dashboardRepoProvider)));
```

Changer la source d'une donnée (remote → cache, → mock de test) se fait à **un seul
endroit** : le provider du datasource/repository. Le domaine et l'UI ne bougent pas
(« point de bascule unique », cf. [CONVENTIONS.md](CONVENTIONS.md) §9).
