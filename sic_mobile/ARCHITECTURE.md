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

Quand le backend Django sera prêt, seule la couche `Data` change. La UI et le métier restent intacts.

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
│   ├── dashboard/                 # Phase 2 — Écran principal
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
│   ├── sim_management/            # Phase 2 — Gestion des puces
│   ├── balance_update/            # Phase 2 — Mise à jour solde
│   ├── alerts/                    # Phase 2 — Alertes solde
│   │
│   ├── auth/                      # Phase 1 (structure préparée)
│   ├── operations/                # Phase 3 (structure préparée)
│   └── history/                   # Phase 4 (structure préparée)
│
└── main.dart                      # Entry point + providers globaux
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

**En Phase 2 (backend pas encore prêt)** : on utilise des **mocks** dans `dashboard_local_datasource.dart`.
**En Phase 3+ (backend prêt)** : on branche `dashboard_remote_datasource.dart`. Rien d'autre ne change.

```dart
// En développement — mock data
class DashboardLocalDatasource {
  Future<AgentSummaryModel> getDashboardSummary() async {
    await Future.delayed(const Duration(milliseconds: 500)); // simule latence
    return AgentSummaryModel.mock();
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
final dioDashboardProvider = Provider((ref) => DashboardLocalDatasource());
final dashboardRepoProvider = Provider((ref) =>
  DashboardRepositoryImpl(ref.read(dioDashboardProvider)));
final getDashboardSummaryProvider = Provider((ref) =>
  GetDashboardSummary(ref.read(dashboardRepoProvider)));
```

Quand on passe au backend réel, on change `DashboardLocalDatasource` par `DashboardRemoteDatasource`. Un seul endroit à modifier.
