# 🔍 AUDIT SIC MOBILE — Rapport complet

**Date :** 11/06/2026  
**Projet :** SIC Mobile — Flutter · Clean Architecture · Riverpod  
**Phase :** Phase 2 (Dashboard + Gestion des puces)  
**Score global :** 7.4/10 → Objectif : **10/10**

---

## 🏁 Objectif

Ce document liste **tous les problèmes** identifiés lors de l'audit, classés par sévérité, avec pour chacun :
- Le fichier exact et la ligne
- Une explication du problème
- L'impact réel
- La correction à appliquer

L'objectif est d'atteindre **10/10 sur toutes les dimensions** avant d'attaquer la Phase suivante

---

## 📊 Tableau des scores actuels vs objectif

| Dimension | Score actuel | Score cible | Écart |
|---|---|---|---|
| Architecture & Clean Code | 9/10 | 10/10 | 1 |
| Riverpod & State | 8/10 | 10/10 | 2 |
| Qualité du code Dart | 9/10 | 10/10 | 1 |
| UI/UX & Cohérence visuelle | 8/10 | 10/10 | 2 |
| Performance & Optimisation | 7/10 | 10/10 | 3 |
| Préparation au backend | 8/10 | 10/10 | 2 |
| Tests & Couverture | 1/10 | 10/10 | 9 |
| Navigation & Routing | 9/10 | 10/10 | 1 |
| Sécurité (Phase 2) | 8/10 | 10/10 | 2 |
| Préparation Phase 3 | 7/10 | 10/10 | 3 |
| **SCORE GLOBAL** | **7.4/10** | **10/10** | **2.6** |

---

# 🚨 BLOQUANTS (Priorité maximale — à corriger immédiatement)

## B-001 : Aucun test écrit — risque de régression majeur

| | |
|---|---|
| **Fichier** | `sic_mobile/test/` (dossier quasi vide) |
| **Problème** | Aucun test unitaire pour les UseCases, Models, Entities, ou Providers. `flutter test` ne trouvera rien à exécuter. Impossible de refactorer ou d'ajouter des features sans casser l'existant. |
| **Impact** | Chaque modification est un pari. Impossible de valider que `maskedPhone` retourne le bon format, que les `fromJson` gèrent les nulls, ou que les `Failure` sont correctement mappés. |
| **Correction** | Écrire les tests suivants : |

### Tests à écrire (minimum vital)

**1. Tests des Entities (Domain layer)**
```dart
// test/features/dashboard/domain/entities/balance_summary_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/balance_summary.dart';

void main() {
  group('BalanceSummary', () {
    test('maskedPhone retourne le format masque (07•••234)', () {
      final balance = BalanceSummary(
        operatorCode: 'OM',
        operatorName: 'Orange Money',
        phoneNumber: '0701234234',
        balance: 250000,
        isLow: false,
        alertThreshold: 50000,
        lastUpdated: DateTime(2024, 1, 15),
      );
      expect(balance.maskedPhone, '07•••234');
    });

    test('maskedPhone retourne le format masque (06•••891)', () {
      final balance = BalanceSummary(
        operatorCode: 'MOOV',
        operatorName: 'Moov Money',
        phoneNumber: '0601238891',
        balance: 35000,
        isLow: true,
        alertThreshold: 50000,
        lastUpdated: DateTime(2024, 1, 15),
      );
      expect(balance.maskedPhone, '06•••891');
    });

    test('isEmpty est true quand balance <= 0', () {
      final balance = BalanceSummary(
        operatorCode: 'OM',
        operatorName: 'Orange Money',
        phoneNumber: '0700000000',
        balance: 0,
        isLow: true,
        alertThreshold: 50000,
        lastUpdated: DateTime.now(),
      );
      expect(balance.isEmpty, isTrue);
    });

    test('isEmpty est false quand balance > 0', () {
      final balance = BalanceSummary(
        operatorCode: 'OM', operatorName: 'Orange Money',
        phoneNumber: '0701234234', balance: 1000,
        isLow: false, alertThreshold: 50000,
        lastUpdated: DateTime.now(),
      );
      expect(balance.isEmpty, isFalse);
    });

    test('copyWith met a jour le champ balance sans modifier isLow', () {
      final balance = BalanceSummary(
        operatorCode: 'OM', operatorName: 'Orange Money',
        phoneNumber: '0701234234', balance: 50000,
        isLow: false, alertThreshold: 50000,
        lastUpdated: DateTime.now(),
      );
      final updated = balance.copyWith(balance: 20000);
      expect(updated.balance, 20000);
      // isLow est recalcule via copyWith : newBalance (20000) < threshold (50000) => true
      expect(updated.isLow, isTrue);
    });
  });
}
```

**2. Tests des UseCases**
```dart
// test/features/dashboard/domain/usecases/get_dashboard_summary_test.dart

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/usecases/usecase.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:sic_mobile/features/dashboard/domain/usecases/get_dashboard_summary.dart';

// Generer avec : flutter pub run build_runner build
@GenerateNiceMocks([MockSpec<DashboardRepository>()])
import 'get_dashboard_summary_test.mocks.dart';

void main() {
  late GetDashboardSummary usecase;
  late MockDashboardRepository mockRepository;

  setUp(() {
    mockRepository = MockDashboardRepository();
    usecase = GetDashboardSummary(mockRepository);
  });

  test('should return AgentSummary when repository succeeds', () async {
    final tSummary = AgentSummary(
      agentCode: 'AGT-001', agentName: 'Test Agent',
      totalBalance: 100000,
      benefits: const BenefitPeriod(today: 0, week: 0, month: 0, total: 0),
      balances: [], transactionCountToday: 0,
    );

    when(mockRepository.getDashboardSummary())
        .thenAnswer((_) async => Right(tSummary));

    final result = await usecase(const NoParams());

    expect(result, Right(tSummary));
    verify(mockRepository.getDashboardSummary()).called(1);
  });

  test('should return ServerFailure when repository fails', () async {
    when(mockRepository.getDashboardSummary())
        .thenAnswer((_) async => Left(const ServerFailure('Erreur test')));

    final result = await usecase(const NoParams());

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure.message, 'Erreur test'),
      (_) => fail('Expected failure'),
    );
  });
}
```

**3. Tests des Models (Data layer)**
```dart
// test/features/dashboard/data/models/balance_summary_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/data/models/balance_summary_model.dart';

void main() {
  group('BalanceSummaryModel fromJson', () {
    test('parse correctement un JSON valide', () {
      final json = {
        'operator_code': 'OM',
        'operator_name': 'Orange Money',
        'phone_number': '0701234234',
        'balance': 250000,
        'is_low': false,
        'alert_threshold': 50000,
        'last_updated': '2024-01-15T10:30:00Z',
        'is_active': true,
      };

      final model = BalanceSummaryModel.fromJson(json);

      expect(model.operatorCode, 'OM');
      expect(model.operatorName, 'Orange Money');
      expect(model.phoneNumber, '0701234234');
      expect(model.balance, 250000);
      expect(model.isLow, isFalse);
      expect(model.alertThreshold, 50000);
      expect(model.isActive, isTrue);
    });

    test('is_active default a true si absent', () {
      final json = {
        'operator_code': 'OM',
        'operator_name': 'Orange Money',
        'phone_number': '0701234234',
        'balance': 0,
        'is_low': true,
        'alert_threshold': 50000,
        'last_updated': '2024-01-15T10:30:00Z',
      };

      final model = BalanceSummaryModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('convertit correctement en JSON via toJson', () {
      final now = DateTime(2024, 1, 15, 10, 30, 0);
      final model = BalanceSummaryModel(
        operatorCode: 'OM', operatorName: 'Orange Money',
        phoneNumber: '0701234234', balance: 250000,
        isLow: false, alertThreshold: 50000,
        lastUpdated: now, isActive: true,
      );

      final json = model.toJson();

      expect(json['operator_code'], 'OM');
      expect(json['balance'], 250000);
      expect(json['last_updated'], '2024-01-15T10:30:00.000Z');
    });
  });
}
```

**4. Tests des utilitaires**
```dart
// test/core/utils/fcfa_formatter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/utils/fcfa_formatter.dart';

void main() {
  group('FcfaFormatter', () {
    test('format ajoute FCFA et formate les milliers', () {
      expect(FcfaFormatter.format(75000), '75\u202f000 FCFA');
    });

    test('formatCompact affiche K pour les milliers', () {
      expect(FcfaFormatter.formatCompact(85000), '85K FCFA');
    });

    test('formatCompact affiche M pour les millions', () {
      expect(FcfaFormatter.formatCompact(1500000), '1,5M FCFA');
    });

    test('formatCompact garde le format normal pour les petits montants', () {
      expect(FcfaFormatter.formatCompact(500), '500 FCFA');
    });

    test('formatBenefit ajoute + pour les montants positifs', () {
      expect(FcfaFormatter.formatBenefit(12500).startsWith('+ '), isTrue);
    });
  });
}
```

---

## B-002 : Repository branché sur le backend au lieu des mocks

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/data/repositories/dashboard_repository_impl.dart` ligne 7 |
| **Problème** | `DashboardRepositoryImpl` utilise `DashboardRemoteDatasource` (appelle le vrai backend Django). En Phase 2, le backend n'est pas disponible. |
| **Impact** | L'app plante au lancement si le backend n'est pas accessible (connexion refusée). Les mocks ne sont pas utilisés. |
| **Correction** | Remplacer `DashboardRemoteDatasource` par `DashboardLocalDatasource` dans le provider : |

**Modification dans `dashboard_provider.dart` :**
```dart
// AVANT (ne marche pas sans backend) :
final dashboardRemoteDatasourceProvider = Provider<DashboardRemoteDatasource>(
  (ref) => DashboardRemoteDatasource(ref.watch(dioProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(dashboardRemoteDatasourceProvider));
});

// APRES (utilise les mocks en Phase 2) :
final dashboardLocalDatasourceProvider = Provider<DashboardLocalDatasource>(
  (ref) => const DashboardLocalDatasource(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl.local(ref.watch(dashboardLocalDatasourceProvider));
});
```

**Modification dans `dashboard_repository_impl.dart` :**
```dart
class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDatasource localDatasource;
  // final DashboardRemoteDatasource remoteDatasource; // Pour Phase 3+

  const DashboardRepositoryImpl(this.localDatasource);

  // Factory pour Phase 3+ :
  // const DashboardRepositoryImpl.remote(this.remoteDatasource);

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    try {
      final summary = await localDatasource.getDashboardSummary();
      return Right(summary);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }
  // ...
}
```

---

# ⚠️ PROBLÈMES IMPORTANTS (à corriger cette semaine)

## P-001 : Flash de loading pendant le refresh du Dashboard

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/presentation/providers/dashboard_provider.dart` lignes 42-44 |
| **Problème** | `state = const AsyncLoading<AgentSummary>()` puis recharge = écran blanc brièvement visible |
| **Impact** | Mauvaise UX : le pull-to-refresh affiche un flash blanc au lieu de garder l'état précédent visible |
| **Correction** | |

```dart
// AVANT :
Future<void> refresh() async {
  state = const AsyncLoading<AgentSummary>();
  state = await AsyncValue.guard(_loadDashboard);
}

// APRES :
Future<void> refresh() async {
  state = await AsyncValue.guard(_loadDashboard);
}
```

---

## P-002 : Section bénéfices non connectée dans le Dashboard

| | |
|---|---|
| **Fichiers** | `sic_mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart` + `benefit_summary_widget.dart` + `benefit_chips.dart` |
| **Problème** | `BenefitSummaryWidget` et `BenefitChips` existent mais ne sont **jamais appelés** dans `DashboardScreen`. Les données mockées de bénéfices (week, month) ne sont pas visibles. |
| **Impact** | L'utilisateur ne voit que le bénéfice du jour dans la hero card, mais pas les périodes semaine/mois. |
| **Correction** | Ajouter dans `_DashboardContent.build()`, après la hero card : |

```dart
// apres la hero card :
// 2.b Benefices
Padding(
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle('Benefices'),
      const SizedBox(height: AppSpacing.sm),
      const BenefitChips(),
      const SizedBox(height: AppSpacing.sm),
      BenefitSummaryWidget(summary: summary),
    ],
  ),
).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideY(
  begin: 0.1, end: 0,
),
```

---

## P-003 : Imports inutilisés

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/sim_management/presentation/widgets/operator_selector.dart` |
| **Problème** | Import de `app_gradients.dart` non utilisé |
| **Impact** | Warning `flutter analyze`, code mort |
| **Correction** | Supprimer la ligne d'import inutile |

```dart
// Supprimer :
// import '../../../../core/constants/app_gradients.dart';
```

---

## P-004 : setState après démontage dans AlertConfigTile

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/alerts/presentation/widgets/alert_config_tile.dart` ligne 116 |
| **Problème** | `_debounce = Timer(...)` appelle `setState` sans vérifier `mounted`. Si le widget est démonté avant la fin du délai, `setState` lève une exception. |
| **Impact** | Crash possible si l'utilisateur quitte l'écran rapidement après avoir modifié un seuil. |
| **Correction** | |

```dart
_debounce = Timer(const Duration(milliseconds: 500), () {
  if (!mounted) return;
  ref.read(alertNotifierProvider.notifier).save(_draftConfig);
});
```

---

## P-005 : Pas de fallback si l'opérateur n'existe pas dans la map

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/presentation/widgets/modify_sim_sheet.dart` lignes 33-34, 74-75 |
| **Problème** | `_operatorCode = widget.balance.operatorCode` sans vérifier que cette clé existe dans `availableOperators`. |
| **Impact** | Si la map change ou si un opérateur backend non standard arrive, le sélecteur peut être vide ou incohérent. |
| **Correction** | |

```dart
// Dans initState() :
final operators = ref.read(availableOperatorsProvider);
_operatorCode = operators.containsKey(widget.balance.operatorCode)
    ? widget.balance.operatorCode
    : operators.keys.first;
```

---

## P-006 : `borderRadius` inutilisé dans Pressable

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/widgets/pressable.dart` lignes 18, 54 |
| **Problème** | Le paramètre `borderRadius` est accepté mais jamais utilisé dans le build. |
| **Impact** | Paramètre mort qui crée de la confusion |
| **Correction** | Soit l'utiliser dans un `ClipRRect`, soit le supprimer : |

```dart
// Option 1 : Supprimer le paramètre
// Retirer borderRadius du constructeur et de la classe

// Option 2 : L'utiliser
@override
Widget build(BuildContext context) {
  return Semantics(
    button: enabled,
    label: widget.semanticLabel,
    child: ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: GestureDetector(
        // ... reste du code
      ),
    ),
  );
}
```

---

## P-007 : Equatable incomplet sur `BalanceSummary`

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/domain/entities/balance_summary.dart` |
| **Problème** | `props` ne contient pas `isActive` (pourtant le champ existe) |
| **Impact** | Deux instances avec le même `isActive` différent seront considérées égales par Equatable |
| **Correction** | |

```dart
@override
List<Object?> get props => [
  operatorCode, operatorName, phoneNumber, balance,
  isLow, alertThreshold, lastUpdated, isActive, // <- ajouter isActive
];
```

---

# 📝 AMÉLIORATIONS (backlog — à faire avant Phase 3)

## A-001 : DioFailure — boucle optimisable

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/network/dio_failure.dart` |
| **Problème** | `_extractMessage` parcourt toutes les valeurs du Map même après avoir trouvé un message. |
| **Correction** | Ajouter `return` après le premier message trouvé |

## A-002 : Gradient non utilisé dans AppGradients

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/constants/app_gradients.dart` |
| **Problème** | `AppGradients.hero` n'a pas de `stops` (0.0, 0.55, 1.0) alors que `BalanceHeroCard` les définit manuellement. |
| **Correction** | Mettre à jour `AppGradients.hero` pour inclure les stops, puis l'utiliser dans `BalanceHeroCard` |

```dart
static const LinearGradient hero = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
  stops: [0.0, 0.55, 1.0],
);
```

## A-003 : SimLocalDatasource mutable et non thread-safe

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/sim_management/data/datasources/sim_local_datasource.dart` |
| **Problème** | La liste `_sims` est statique et mutable. Si deux appels modifient la liste, le second écrase le premier. |
| **Correction** | Utiliser Hive (déjà dans pubspec.yaml) comme `AlertLocalDatasource` le fait déjà |

## A-004 : `hasSession` ne vérifie que le refresh token

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/storage/token_storage.dart` |
| **Problème** | `hasSession()` ne vérifie que le refresh token. Si seul l'access token est présent, la session est considérée valide mais le refresh échouera. |
| **Correction** | Vérifier les deux tokens ou au moins le refresh |

## A-005 : ChoiceChip dans BenefitChips non stylisé SIC

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/presentation/widgets/benefit_chips.dart` |
| **Problème** | `ChoiceChip` Material Design par défaut, pas aligné avec la palette SIC. Le widget n'est pas utilisé actuellement (P-002). |
| **Correction** | Quand le widget sera connecté, uniformiser le style avec les cards (bordure `AppColors.border`, fond `AppColors.surface`, sélection `AppColors.primary`) |

---

# 🎯 PERFORMANCE (à vérifier et optimiser)

## PERF-001 : Animer sans Consumer inutile

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart` |
| **Problème** | `ref.watch(dashboardNotifierProvider)` dans `DashboardScreen` rebuild tout l'écran même si seul le solde change. |
| **Correction** | Découper en sous-widgets qui utilisent `.select()` pour ne rebuild que ce qui change |

```dart
// Exemple : sous-widget qui ne rebuild que si le solde change
class _BalanceSection extends ConsumerWidget {
  const _BalanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(
      dashboardNotifierProvider.select((s) => s.valueOrNull?.totalBalance ?? 0),
    );
    final isVisible = ref.watch(heroBalanceVisibleProvider);
    return BalanceHeroCard(
      totalBalance: totalBalance,
      // ...
    );
  }
}
```

## PERF-002 : Timer non annulé dans le carousel

| | |
|---|---|
| **Fichier** | À créer : bannière carousel (pas encore implémenté) |
| **Problème** | Si un `Timer.periodic` est utilisé pour le carousel de bannières, il doit être annulé dans `dispose()`. |
| **Correction** | Anticiper : utiliser un `StatefulWidget` avec `_timer?.cancel()` dans `dispose()` |

## PERF-003 : Images sans cache

| | |
|---|---|
| **Fichier** | Partout dans le projet |
| **Problème** | Les logos opérateurs (`OperatorLogo`) sont rendus en gradient + texte, pas d'images assets. C'est bien pour l'instant. Quand des vraies images seront ajoutées, utiliser `cacheWidth` et `cacheHeight`. |
| **Correction** | À faire quand les assets sont ajoutés |

---

# 🔧 PRÉPARATION BACKEND (avant connexion réelle)

## BACK-001 : Aligner les endpoints avec BACKEND_CONTRACT.md

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/constants/api_constants.dart` |
| **Problème** | Les endpoints actuels sont sous `/api/` (pas `/api/v1/`). Le contrat dit `/api/v1/`. Même si Django a `/api/`, l'alignement évite les confusions. |
| **Correction** | Vérifier avec le dev backend puis mettre à jour `baseUrl` ou les chemins |

## BACK-002 : Ajouter les endpoints manquants pour Phase 3

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/constants/api_constants.dart` |
| **Problème** | Les endpoints de transactions (deposit, withdraw, conversion, webhook) ne sont pas encore dans ApiConstants. Ils sont dans le contrat mais pas dans le code. |
| **Correction** | Ajouter avant Phase 3 : |

```dart
static const deposit = '/transactions/deposit/';
static const withdraw = '/transactions/withdraw/';
static const conversion = '/transactions/conversion/';
static const webhook = '/transactions/webhook/';
```

## BACK-003 : Intercepteur 401 avec notification utilisateur

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/network/network_providers.dart` |
| **Problème** | Quand le refresh échoue, `onSessionExpired()` est appelé, mais l'utilisateur ne voit aucun message. Il est juste redirigé vers le login sans explication. |
| **Correction** | Ajouter un système de notification (SnackBar ou toast) avant le redirect |

```dart
onSessionExpired: () {
  // Afficher un toast avant de déconnecter
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Session expiree. Reconnectez-vous.')),
  );
  ref.read(authControllerProvider.notifier).onExpired();
},
```

---

# 🧪 TESTS (Plan complet pour atteindre 10/10)

## Objectif : Couverture minimale par couche

| Couche | Fichiers à tester | Tests requis |
|---|---|---|
| **Domain — Entities** | `balance_summary.dart`, `agent_summary.dart`, `benefit_period.dart`, `sim_card.dart` | Propriétés, getters (`maskedPhone`, `isEmpty`, `isLow`, `agentInitials`), `copyWith`, `Equatable.props` |
| **Domain — UseCases** | `get_dashboard_summary.dart`, `refresh_balance.dart`, `get_sims.dart`, `add_sim.dart`, `toggle_sim.dart`, `update_balance.dart`, `get_alert_configs.dart`, `save_alert_config.dart` | Chaque UseCase : 1 test succès + 1 test échec |
| **Data — Models** | `agent_summary_model.dart`, `balance_summary_model.dart`, `sim_card_model.dart` | `fromJson` (valide, nulls, cas limites), `toJson`, `mock()` |
| **Data — Repositories** | `dashboard_repository_impl.dart`, `sim_repository_impl.dart` | Succès → Right, Exception → Left(Failure) |
| **Core — Utils** | `fcfa_formatter.dart`, `date_formatter.dart`, `validators.dart` | Formatages, validations (numéro, montant) |
| **Presentation — Providers** | `dashboard_provider.dart`, `sim_provider.dart` | Pas de test unitaire direct — tester via les UseCases |

## Liste des fichiers de test à créer

```
test/
├── core/
│   └── utils/
│       ├── fcfa_formatter_test.dart
│       ├── date_formatter_test.dart
│       └── validators_test.dart
├── features/
│   ├── dashboard/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── balance_summary_test.dart
│   │   │   │   ├── agent_summary_test.dart
│   │   │   │   └── benefit_period_test.dart
│   │   │   └── usecases/
│   │   │       ├── get_dashboard_summary_test.dart
│   │   │       └── refresh_balance_test.dart
│   │   └── data/
│   │       └── models/
│   │           ├── balance_summary_model_test.dart
│   │           ├── agent_summary_model_test.dart
│   │           └── benefit_period_model_test.dart
│   ├── sim_management/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── sim_card_test.dart
│   │   │   └── usecases/
│   │   │       ├── get_sims_test.dart
│   │   │       ├── add_sim_test.dart
│   │   │       └── toggle_sim_test.dart
│   │   └── data/
│   │       └── models/
│   │           └── sim_card_model_test.dart
│   ├── balance_update/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── balance_update_test.dart
│   │   │   └── usecases/
│   │   │       ├── update_balance_test.dart
│   │   │       └── get_balance_history_test.dart
│   │   └── data/
│   │       └── models/
│   │           └── balance_update_model_test.dart
│   └── alerts/
│       ├── domain/
│       │   ├── entities/
│       │   │   └── alert_config_test.dart
│       │   └── usecases/
│       │       ├── get_alert_configs_test.dart
│       │       └── save_alert_config_test.dart
│       └── data/
│           └── models/
│               └── alert_config_model_test.dart
```

## Commandes pour les tests

```bash
# Lancer tous les tests
flutter test

# Avec couverture
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Générer les mocks (après avoir ajouté @GenerateNiceMocks)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

# 🌐 NAVIGATION (derniers ajustements)

## NAV-001 : Routes Phase 3 préparées

| | |
|---|---|
| **Fichier** | `sic_mobile/lib/core/router/app_router.dart` |
| **Problème** | Les routes pour les opérations (depot, retrait, transfert) ne sont pas encore définies. |
| **Correction** | Ajouter des placeholders avant Phase 3 : |

```dart
// Dans app_router.dart, ajouter dans la ShellRoute :
GoRoute(
  path: '/operations/depot',
  builder: (context, state) => const PlaceholderScreen(label: 'Depot'),
),
GoRoute(
  path: '/operations/retrait',
  builder: (context, state) => const PlaceholderScreen(label: 'Retrait'),
),
GoRoute(
  path: '/operations/transfert',
  builder: (context, state) => const PlaceholderScreen(label: 'Transfert'),
),
GoRoute(
  path: '/operations/recharge',
  builder: (context, state) => const PlaceholderScreen(label: 'Recharge'),
),
```

## NAV-002 : Vérifier que tous les callbacks pointent vers des routes existantes

| | |
|---|---|
| **Fichiers** | `sim_wallet_stack.dart`, `sim_cards_section.dart`, `dashboard_screen.dart` |
| **Problème** | Les callbacks `onHistoryTap`, `onModifyTap`, `onRechargeTap` dans `SimBalanceCard` et `OperationsBar` pointent vers `_comingSoon` (snackbar). Normal en Phase 2, mais à vérifier avant Phase 3. |
| **Correction** | Remplacer `_comingSoon` par `context.go('/operations/...')` quand les routes existeront |

---

# 🛡️ SÉCURITÉ (préparer pour la production)

## SEC-001 : Certificate Pinning

| | |
|---|---|
| **Problème** | Aucun certificate pinning n'est implémenté. En production, un attaquant pourrait intercepter les requêtes avec un certificat frauduleux. |
| **Correction** | Ajouter avant la mise en production. Marquer en TODO pour Phase 5 |

```dart
// TODO SECURITY: Implement certificate pinning before production
// Utiliser dio interceptor avec SHA-256 du certificat backend
```

## SEC-002 : .env dans .gitignore

| | |
|---|---|
| **Fichier** | `sic_mobile/.gitignore` |
| **Problème** | Vérifier que `.env` est bien dans `.gitignore` pour ne pas commit les clés API |
| **Correction** | Ajouter si manquant : `.env` dans `.gitignore` |

## SEC-003 : Ne pas logger les numéros de téléphone

| | |
|---|---|
| **Problème** | Si un `print()` ou `debugPrint()` affiche `phoneNumber` en clair, c'est une fuite de données personnelles (RGPD). |
| **Correction** | Utiliser `maskedPhone` dans les logs de debug. Vérifier qu'aucun `print()` ne traîne dans le code. |

```bash
# Chercher les prints dangereux
grep -rn "print.*phone\|print.*telephone\|print.*Phone" lib/
```

---

# 📋 CHECKLIST 10/10 — Synthèse

## À faire immédiatement (bloquants)

- [ ] **[B-001]** Écrire les tests unitaires de base (4 fichiers minimum) — ~2h
- [ ] **[B-002]** Basculer `DashboardRepositoryImpl` vers le local datasource — ~30min

## À faire cette semaine

- [ ] **[P-001]** Supprimer le flash de loading dans `DashboardNotifier.refresh()` — ~10min
- [ ] **[P-002]** Connecter `BenefitSummaryWidget` et `BenefitChips` dans le Dashboard — ~30min
- [ ] **[P-003]** Supprimer les imports inutilisés — ~10min
- [ ] **[P-004]** Ajouter vérification `mounted` dans `AlertConfigTile` — ~10min
- [ ] **[P-005]** Fallback sur `_operatorCode` dans `ModifySimSheet` — ~15min
- [ ] **[P-006]** Utiliser ou supprimer `borderRadius` dans `Pressable` — ~10min
- [ ] **[P-007]** Ajouter `isActive` dans les props Equatable de `BalanceSummary` — ~5min

## Avant la Phase 3

- [ ] **[A-001]** Optimiser la boucle dans `_extractMessage` — ~10min
- [ ] **[A-002]** Aligner `AppGradients.hero` avec `BalanceHeroCard` — ~15min
- [ ] **[A-003]** Migrer `SimLocalDatasource` vers Hive — ~1h
- [ ] **[A-004]** Renforcer `hasSession()` — ~10min
- [ ] **[A-005]** Styliser `ChoiceChip` dans `BenefitChips` — ~15min
- [ ] **[PERF-001]** Optimiser les rebuilds avec `.select()` — ~30min
- [ ] **[PERF-002]** Anticiper l'annulation du Timer carousel — ~10min
- [ ] **[BACK-001]** Aligner les endpoints API — ~30min
- [ ] **[BACK-002]** Ajouter les endpoints transactions dans ApiConstants — ~10min
- [ ] **[BACK-003]** Notification utilisateur sur session expirée — ~30min
- [ ] **[NAV-001]** Ajouter les routes placeholders Phase 3 — ~20min
- [ ] **[SEC-001]** TODO certificate pinning dans le code — ~5min
- [ ] **[SEC-002]** Vérifier `.gitignore` — ~5min
- [ ] **[SEC-003]** Vérifier les prints de données sensibles — ~15min
- [ ] **Écrire TOUS les tests** (voir liste complète section Tests) — ~4h
- [ ] Lancer `flutter analyze` et corriger tout warning/erreur — ~15min
- [ ] Lancer `flutter test` et vérifier 100% de réussite — ~5min
- [ ] Lancer `flutter test --coverage` et visiter le rapport — ~10min

## Temps total estimé

| Priorité | Temps |
|---|---|
| Bloquants | 2h30 |
| Importants | 1h20 |
| Backlog avant Phase 3 | 7h20 |
| **Total** | **~11h10** |

---

## ✅ RÉSULTAT ATTENDU

Quand cette checklist sera complétée :

```bash
flutter analyze   # → 0 erreurs, 0 warnings
flutter test      # → All tests passed (20+ tests)
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
                  # → Couverture > 60%
```

Et le projet sera prêt pour aborder la Phase 3 (moteur de compensation inter-réseaux) dans les meilleures conditions.

---

*Document généré depuis l'audit complet du code source SIC Mobile (11/06/2026).*
