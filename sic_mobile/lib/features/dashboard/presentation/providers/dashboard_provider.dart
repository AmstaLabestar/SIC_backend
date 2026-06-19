import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/privacy_provider.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/agent_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../domain/usecases/refresh_balance.dart';

enum DashboardPeriod { today, week, month }

final dashboardRemoteDatasourceProvider = Provider<DashboardRemoteDatasource>(
  (ref) => DashboardRemoteDatasource(ref.watch(dioProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(dashboardRemoteDatasourceProvider));
});

final getDashboardSummaryProvider = Provider<GetDashboardSummary>((ref) {
  return GetDashboardSummary(ref.watch(dashboardRepositoryProvider));
});

final refreshBalanceProvider = Provider<RefreshBalance>((ref) {
  return RefreshBalance(ref.watch(dashboardRepositoryProvider));
});

final selectedPeriodProvider = StateProvider<DashboardPeriod>(
  (ref) => DashboardPeriod.today,
);

/// Visibilite du solde total de la hero card. Defaut pilote par la preference
/// de confidentialite (masquer les soldes) ; l'oeil reste un override de session.
final heroBalanceVisibleProvider = StateProvider<bool>(
  (ref) => !ref.watch(hideBalancesProvider),
);

/// Visibilite du solde d'une SIM, par operatorCode. Meme defaut que la hero.
final simVisibilityProvider = StateProvider.family<bool, String>(
  (ref, operatorCode) => !ref.watch(hideBalancesProvider),
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
    // Pas de flash blanc : on garde l'etat precedent visible pendant le reload
    // (le RefreshIndicator fournit deja un retour visuel).
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
    required String puceId,
    required double newBalance,
    required DateTime updatedAt,
  }) {
    final currentSummary = state.valueOrNull;
    if (currentSummary == null) {
      return;
    }

    final updatedBalances = currentSummary.balances.map((balance) {
      if (balance.id != puceId) {
        return balance;
      }

      return balance.copyWith(balance: newBalance, lastUpdated: updatedAt);
    }).toList();

    state = AsyncData(currentSummary.copyWith(balances: updatedBalances));
  }

  /// Modifie une SIM cote backend (`PATCH /puces/{id}/`) puis rafraichit le
  /// dashboard (source de verite). Retourne un message d'erreur ou `null`.
  Future<String?> updateSim({
    required String id,
    required String operatorCode,
    required String phoneNumber,
    required bool isActive,
  }) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final result = await repo.updatePuce(
      id: id,
      operatorCode: operatorCode,
      phoneNumber: phoneNumber,
      isActive: isActive,
    );
    return result.fold(
      (failure) async => failure.message,
      (_) async {
        await refresh();
        return null;
      },
    );
  }

  /// Supprime une SIM cote backend (`DELETE /puces/{id}/`) puis rafraichit.
  /// Retourne un message d'erreur ou `null`.
  Future<String?> removeSim(String id) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final result = await repo.deletePuce(id);
    return result.fold(
      (failure) async => failure.message,
      (_) async {
        await refresh();
        return null;
      },
    );
  }

  /// Ajoute une SIM cote backend (`POST /puces/`) puis rafraichit.
  /// Retourne un message d'erreur ou `null`.
  Future<String?> addSim({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final result = await repo.createPuce(
      operatorCode: operatorCode,
      phoneNumber: phoneNumber,
    );
    return result.fold(
      (failure) async => failure.message,
      (_) async {
        await refresh();
        return null;
      },
    );
  }

  Future<AgentSummary> _loadDashboard() async {
    final usecase = ref.read(getDashboardSummaryProvider);
    final result = await usecase(const NoParams());

    return result.fold((failure) => throw failure, (summary) => summary);
  }
}
