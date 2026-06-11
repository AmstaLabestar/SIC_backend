# Conventions — SIC Mobile

## 1. Conventional Commits

Chaque commit suit le format : `type(scope): description courte`

| Type | Quand l'utiliser |
|---|---|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `chore` | Config, dépendances, outillage |
| `style` | Formatage, espaces (pas de logique) |
| `refactor` | Refactoring sans nouveau comportement |
| `test` | Ajout ou modification de tests |
| `docs` | Documentation uniquement |
| `perf` | Amélioration de performance |

**Exemples :**
```
feat(dashboard): add balance summary cards
feat(sim): implement add SIM form with validation
fix(dashboard): correct FCFA formatting for large amounts
chore: add riverpod dependencies to pubspec
test(dashboard): add unit tests for GetDashboardSummary usecase
docs: update PHASE2 with step 3 details
```

**Règles :**
- Description en **anglais**, minuscules, sans point final
- Maximum 72 caractères sur la première ligne
- Corps du commit optionnel après une ligne vide

---

## 2. Branches

```
main          ← production, protégée
develop       ← intégration, base de travail
feature/phase2-dashboard        ← écran dashboard
feature/phase2-sim-management   ← gestion puces
feature/phase2-balance-update   ← mise à jour solde
feature/phase2-alerts           ← alertes solde
fix/dashboard-balance-overflow  ← correction bug
```

**Workflow :**
1. Toujours partir de `develop` pour créer une feature
2. PR de `feature/*` → `develop`
3. PR de `develop` → `main` uniquement après validation complète d'une phase

```powershell
# Créer une feature
git checkout develop
git pull origin develop
git checkout -b feature/phase2-dashboard

# Terminer une feature
git add .
git commit -m "feat(dashboard): complete dashboard screen Phase 2"
git push origin feature/phase2-dashboard
# → Ouvrir une Pull Request sur GitHub vers develop
```

---

## 3. Nommage Dart / Flutter

### Fichiers
```
snake_case pour tous les fichiers Dart
dashboard_screen.dart       ✓
dashboardScreen.dart        ✗
DashboardScreen.dart        ✗
```

### Classes
```dart
PascalCase pour les classes
class DashboardScreen       ✓
class dashboardScreen       ✗
```

### Variables et fonctions
```dart
camelCase
final balanceSummary = ...  ✓
final balance_summary = ... ✗

void refreshBalances() {}   ✓
void RefreshBalances() {}   ✗
```

### Constantes
```dart
camelCase (convention Dart — pas de SCREAMING_SNAKE)
const defaultTimeout = 30000;   ✓
const DEFAULT_TIMEOUT = 30000;  ✗
```

### Providers Riverpod
```dart
// Toujours suffixer par Provider ou Notifier
final dashboardNotifierProvider = ...
final balanceSummaryProvider = ...
```

---

## 4. Structure d'un fichier Dart

Ordre des éléments dans un fichier :

```dart
// 1. Imports dart: en premier
import 'dart:async';

// 2. Imports package: ensuite
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 3. Imports relatifs en dernier
import '../domain/entities/balance_summary.dart';
import '../../../core/widgets/sic_button.dart';

// 4. Une ligne vide entre chaque groupe d'imports

// 5. Constantes du fichier (si besoin)
const _animationDuration = Duration(milliseconds: 300);

// 6. La classe principale
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...
  }
}

// 7. Widgets privés du fichier en dessous
class _BalanceSection extends StatelessWidget { ... }
```

---

## 5. Widgets Flutter

### Toujours `const` quand possible
```dart
const SizedBox(height: 16)   ✓  (pas de rebuild inutile)
SizedBox(height: 16)         ✗
```

### Extraire les widgets dès 3 niveaux d'imbrication
```dart
// ✗ À éviter — trop imbriqué
Column(children: [
  Padding(padding: ..., child:
    Row(children: [
      Expanded(child:
        Text(...)
      )
    ])
  )
])

// ✓ Extraire en widget privé
Column(children: [
  const _BalanceHeader(),
  const _OperatorRow(),
])
```

### Nommer les widgets extraits avec underscore (privés)
```dart
class _BalanceCard extends StatelessWidget { ... }    ✓
class BalanceCardInternal extends StatelessWidget {}  ✗
```

---

## 6. Gestion des états Riverpod

### Toujours `AsyncNotifier` pour les données asynchrones
```dart
@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  @override
  Future<AgentSummary> build() => _fetchSummary();
}
```

### Toujours gérer les 3 états dans la UI
```dart
ref.watch(dashboardNotifierProvider).when(
  loading: () => const SicLoading(),    // ← jamais oublier
  error: (e, _) => SicErrorWidget(e),  // ← jamais oublier
  data: (data) => _Content(data),
);
```

---

## 7. Commentaires

```dart
// TODO: brancher sur le vrai endpoint Django quand disponible
// FIXME: gestion du cas offline à implémenter
// NOTE: le taux SIC est configurable côté admin — ne pas hardcoder

/// Documentation publique de la méthode (triple slash)
/// Utilisée par l'IDE pour les tooltips
Future<void> refreshBalance(String operatorCode) async { ... }
```

Éviter les commentaires qui répètent le code :
```dart
// ✗ Inutile
// Retourne la balance
return balance;

// ✓ Utile — explique le POURQUOI
// Délai simulé pour reproduire la latence API en dev
await Future.delayed(const Duration(milliseconds: 500));
```

---

## 8. Tests

Chaque UseCase doit avoir un test unitaire :

```
test/
├── features/
│   ├── dashboard/
│   │   ├── usecases/
│   │   │   └── get_dashboard_summary_test.dart
│   │   └── repositories/
│   │       └── dashboard_repository_impl_test.dart
│   └── sim_management/
│       └── usecases/
│           └── get_sims_test.dart
```

Nommage des tests :
```dart
test('should return AgentSummary when call is successful', () { ... });
test('should return ServerFailure when API returns 500', () { ... });
test('should return CacheFailure when local storage is empty', () { ... });
```
