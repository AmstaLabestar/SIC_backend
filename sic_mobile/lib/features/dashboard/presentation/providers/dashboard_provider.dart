import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/dashboard_local_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/agent_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../domain/usecases/refresh_balance.dart';

enum DashboardBenefitPeriod { today, week, month }

final dashboardLocalDatasourceProvider = Provider<DashboardLocalDatasource>(
  (ref) => const DashboardLocalDatasource(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(dashboardLocalDatasourceProvider));
});

final getDashboardSummaryProvider = Provider<GetDashboardSummary>((ref) {
  return GetDashboardSummary(ref.watch(dashboardRepositoryProvider));
});

final refreshBalanceProvider = Provider<RefreshBalance>((ref) {
  return RefreshBalance(ref.watch(dashboardRepositoryProvider));
});

final selectedBenefitPeriodProvider = StateProvider<DashboardBenefitPeriod>(
  (ref) => DashboardBenefitPeriod.today,
);

/// Visibilite du solde total de la hero card (defaut: visible).
final heroBalanceVisibleProvider = StateProvider<bool>((ref) => true);

/// Visibilite du solde d'une SIM, par operatorCode (defaut: visible).
final simVisibilityProvider = StateProvider.family<bool, String>(
  (ref, operatorCode) => true,
);

/// Page active du carousel de bannieres.
final bannerPageProvider = StateProvider<int>((ref) => 0);

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, AgentSummary>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<AgentSummary> {
  @override
  Future<AgentSummary> build() {
    return _loadDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<AgentSummary>();
    state = await AsyncValue.guard(_loadDashboard);
  }

  Future<void> refreshOperatorBalance(String operatorCode) async {
    final usecase = ref.read(refreshBalanceProvider);
    final result = await usecase(
      RefreshBalanceParams(operatorCode: operatorCode),
    );

    await result.fold(
      (failure) {
        state = AsyncError<AgentSummary>(failure, StackTrace.current);
        return Future<void>.value();
      },
      (_) => refresh(),
    );
  }

  void applyBalanceUpdate({
    required String operatorCode,
    required double newBalance,
    required DateTime updatedAt,
  }) {
    final currentSummary = state.valueOrNull;
    if (currentSummary == null) {
      return;
    }

    final updatedBalances = currentSummary.balances.map((balance) {
      if (balance.operatorCode != operatorCode) {
        return balance;
      }

      return balance.copyWith(balance: newBalance, lastUpdated: updatedAt);
    }).toList();

    state = AsyncData(currentSummary.copyWith(balances: updatedBalances));
  }

  /// Met a jour les infos d'une SIM (operateur, numero, statut actif).
  void updateSim({
    required String originalOperatorCode,
    required String operatorCode,
    required String operatorName,
    required String phoneNumber,
    required bool isActive,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.balances.map((balance) {
      if (balance.operatorCode != originalOperatorCode) {
        return balance;
      }
      return balance.copyWith(
        operatorCode: operatorCode,
        operatorName: operatorName,
        phoneNumber: phoneNumber,
        isActive: isActive,
        lastUpdated: DateTime.now(),
      );
    }).toList();

    state = AsyncData(current.copyWith(balances: updated));
  }

  /// Supprime une SIM de la liste (recalcule le solde total).
  void removeSim(String operatorCode) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.balances
        .where((balance) => balance.operatorCode != operatorCode)
        .toList();

    state = AsyncData(current.copyWith(balances: updated));
  }

  Future<AgentSummary> _loadDashboard() async {
    final usecase = ref.read(getDashboardSummaryProvider);
    final result = await usecase(const NoParams());

    return result.fold((failure) => throw failure, (summary) => summary);
  }
}
