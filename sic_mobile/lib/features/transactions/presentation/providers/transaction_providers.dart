import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/agent_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

final transactionRemoteDatasourceProvider =
    Provider<TransactionRemoteDatasource>(
  (ref) => TransactionRemoteDatasource(ref.watch(dioProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(
    ref.watch(transactionRemoteDatasourceProvider),
  );
});

/// Historique des transactions de l'agent (`GET /transactions/`).
final transactionsNotifierProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<AgentTransaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<AgentTransaction>> {
  @override
  Future<List<AgentTransaction>> build() => _load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<List<AgentTransaction>> _load() async {
    final repo = ref.read(transactionRepositoryProvider);
    final result = await repo.getTransactions();
    return result.fold((failure) => throw failure, (txns) => txns);
  }
}
