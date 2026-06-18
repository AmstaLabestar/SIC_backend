import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../domain/entities/balance_update.dart';
import '../../domain/repositories/balance_repository.dart';
import '../datasources/balance_remote_datasource.dart';

class BalanceRepositoryImpl implements BalanceRepository {
  const BalanceRepositoryImpl(this.remoteDatasource);

  final BalanceRemoteDatasource remoteDatasource;

  @override
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String puceId,
    required double newBalance,
    required String? pinToken,
  }) async {
    try {
      final update = await remoteDatasource.setBalance(
        puceId: puceId,
        newBalance: newBalance,
        pinToken: pinToken,
      );
      return Right(update);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }
}
