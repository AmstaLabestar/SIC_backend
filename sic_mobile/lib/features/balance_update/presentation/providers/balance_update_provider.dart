import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/balance_remote_datasource.dart';
import '../../data/repositories/balance_repository_impl.dart';
import '../../domain/repositories/balance_repository.dart';
import '../../domain/usecases/update_balance.dart';

final balanceRemoteDatasourceProvider = Provider<BalanceRemoteDatasource>(
  (ref) => BalanceRemoteDatasource(ref.watch(dioProvider)),
);

/// Point de bascule unique de la feature : changer la source de la MAJ solde
/// (remote, mock de test) se fait ici seul.
final balanceRepositoryProvider = Provider<BalanceRepository>((ref) {
  return BalanceRepositoryImpl(ref.watch(balanceRemoteDatasourceProvider));
});

final updateBalanceProvider = Provider<UpdateBalance>((ref) {
  return UpdateBalance(ref.watch(balanceRepositoryProvider));
});
