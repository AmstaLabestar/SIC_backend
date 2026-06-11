import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/balance_update.dart';
import '../../domain/repositories/balance_repository.dart';
import '../datasources/balance_local_datasource.dart';

class BalanceRepositoryImpl implements BalanceRepository {
  const BalanceRepositoryImpl(this.localDatasource);

  final BalanceLocalDatasource localDatasource;

  @override
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String operatorCode,
    required double previousBalance,
    required double newBalance,
  }) async {
    try {
      final update = await localDatasource.updateBalance(
        operatorCode: operatorCode,
        previousBalance: previousBalance,
        newBalance: newBalance,
      );
      return Right(update);
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de mettre a jour le solde.'));
    }
  }

  @override
  Future<Either<Failure, List<BalanceUpdate>>> getBalanceHistory(
    String operatorCode,
  ) async {
    try {
      final history = await localDatasource.getBalanceHistory(operatorCode);
      return Right(history);
    } catch (_) {
      return const Left(ServerFailure('Impossible de charger l historique.'));
    }
  }
}
