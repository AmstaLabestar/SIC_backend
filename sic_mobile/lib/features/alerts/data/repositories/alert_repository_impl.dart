import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/alert_config.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_local_datasource.dart';
import '../models/alert_config_model.dart';

class AlertRepositoryImpl implements AlertRepository {
  const AlertRepositoryImpl(this.localDatasource);

  final AlertLocalDatasource localDatasource;

  @override
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs() async {
    try {
      final configs = await localDatasource.getAlertConfigs();
      return Right(configs);
    } catch (_) {
      return const Left(CacheFailure('Impossible de charger les alertes.'));
    }
  }

  @override
  Future<Either<Failure, AlertConfig>> saveAlertConfig(
    AlertConfig config,
  ) async {
    try {
      final savedConfig = await localDatasource.saveAlertConfig(
        AlertConfigModel.fromEntity(config),
      );
      return Right(savedConfig);
    } catch (_) {
      return const Left(CacheFailure('Impossible de sauvegarder l alerte.'));
    }
  }
}
