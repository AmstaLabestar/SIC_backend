import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../domain/entities/alert_config.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_remote_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  const AlertRepositoryImpl(this.remoteDatasource);

  final AlertRemoteDatasource remoteDatasource;

  @override
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs() async {
    try {
      final configs = await remoteDatasource.getAlertConfigs();
      return Right(configs);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, AlertConfig>> updateAlertConfig({
    required String id,
    required double threshold,
    required bool isEnabled,
  }) async {
    try {
      final config = await remoteDatasource.updateAlertConfig(
        id: id,
        threshold: threshold,
        isEnabled: isEnabled,
      );
      return Right(config);
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }
}
