import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/balance_local_datasource.dart';
import '../../data/repositories/balance_repository_impl.dart';
import '../../domain/entities/balance_update.dart';
import '../../domain/repositories/balance_repository.dart';
import '../../domain/usecases/get_balance_history.dart';
import '../../domain/usecases/update_balance.dart';

final balanceLocalDatasourceProvider = Provider<BalanceLocalDatasource>(
  (ref) => BalanceLocalDatasource(),
);

final balanceRepositoryProvider = Provider<BalanceRepository>((ref) {
  return BalanceRepositoryImpl(ref.watch(balanceLocalDatasourceProvider));
});

final updateBalanceProvider = Provider<UpdateBalance>((ref) {
  return UpdateBalance(ref.watch(balanceRepositoryProvider));
});

final getBalanceHistoryProvider = Provider<GetBalanceHistory>((ref) {
  return GetBalanceHistory(ref.watch(balanceRepositoryProvider));
});

final balanceHistoryProvider =
    FutureProvider.family<List<BalanceUpdate>, String>((ref, operatorCode) async {
  final usecase = ref.watch(getBalanceHistoryProvider);
  final result = await usecase(
    GetBalanceHistoryParams(operatorCode: operatorCode),
  );

  return result.fold((failure) => throw failure, (history) => history);
});
