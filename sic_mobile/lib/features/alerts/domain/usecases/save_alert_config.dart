import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/alert_config.dart';
import '../repositories/alert_repository.dart';

class SaveAlertConfig implements UseCase<AlertConfig, AlertConfig> {
  const SaveAlertConfig(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, AlertConfig>> call(AlertConfig params) {
    return repository.saveAlertConfig(params);
  }
}
