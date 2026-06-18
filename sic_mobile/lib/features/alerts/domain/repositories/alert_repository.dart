import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/alert_config.dart';

abstract class AlertRepository {
  /// Liste les alertes de solde des puces de l'agent (source : backend).
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs();

  /// Met a jour le seuil / l'activation d'une alerte donnee.
  Future<Either<Failure, AlertConfig>> updateAlertConfig({
    required String id,
    required double threshold,
    required bool isEnabled,
  });
}
