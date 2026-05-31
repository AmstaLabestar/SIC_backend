import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/data/models/transaction.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';

/// Provider for SIC Repository
final sicRepositoryProvider = Provider<SicRepository>((ref) {
  return SicRepository();
});

/// Provider for Agent Profile
final agentProfileProvider = FutureProvider<Agent?>((ref) async {
  final repo = ref.watch(sicRepositoryProvider);
  return await repo.getProfile();
});

/// Provider for Puces
final pucesProvider = FutureProvider<List<Puce>>((ref) async {
  final repo = ref.watch(sicRepositoryProvider);
  return await repo.getPuces();
});

/// Provider for Transactions
final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repo = ref.watch(sicRepositoryProvider);
  return await repo.getTransactions();
});

/// Provider for total balance
final totalBalanceProvider = Provider<double>((ref) {
  final pucesAsync = ref.watch(pucesProvider);
  return pucesAsync.maybeWhen(
    data: (puces) => puces.fold(0.0, (sum, puce) => sum + puce.balance),
    orElse: () => 0.0,
  );
});

/// Provider for selected bottom nav index
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for dark mode
final isDarkModeProvider = StateProvider<bool>((ref) => false);

/// Provider for auth state
final isAuthenticatedProvider = StateProvider<bool>((ref) {
  final repo = ref.read(sicRepositoryProvider);
  return repo.isLoggedIn;
});

/// Provider for loading states
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider for error messages
final errorMessageProvider = StateProvider<String?>((ref) => null);