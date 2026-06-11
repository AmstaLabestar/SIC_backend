import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/balance_update.dart';

abstract class BalanceRepository {
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String operatorCode,
    required double previousBalance,
    required double newBalance,
  });

  Future<Either<Failure, List<BalanceUpdate>>> getBalanceHistory(
    String operatorCode,
  );
}
