import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/agent_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.localDatasource);

  final DashboardLocalDatasource localDatasource;

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    try {
      final summary = await localDatasource.getDashboardSummary();
      return Right(summary);
    } on NetworkException {
      return const Left(NetworkFailure());
    } on CacheException catch (error) {
      return Left(CacheFailure(error.message));
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de charger le dashboard.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode) async {
    try {
      await localDatasource.refreshBalance(operatorCode);
      return const Right(unit);
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de rafraichir ce solde.'));
    }
  }
}
