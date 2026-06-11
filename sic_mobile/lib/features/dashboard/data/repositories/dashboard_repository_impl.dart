import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../domain/entities/agent_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.remoteDatasource);

  final DashboardRemoteDatasource remoteDatasource;

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    try {
      final summary = await remoteDatasource.getDashboardSummary();
      return Right(summary);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode) async {
    try {
      await remoteDatasource.refreshBalance(operatorCode);
      return const Right(unit);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }
}
