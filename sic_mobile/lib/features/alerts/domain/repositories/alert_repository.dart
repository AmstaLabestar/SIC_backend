import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/alert_config.dart';

abstract class AlertRepository {
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs();

  Future<Either<Failure, AlertConfig>> saveAlertConfig(AlertConfig config);
}
