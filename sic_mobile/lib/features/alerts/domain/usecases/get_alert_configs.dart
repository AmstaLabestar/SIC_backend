import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/alert_config.dart';
import '../repositories/alert_repository.dart';

class GetAlertConfigs implements UseCase<List<AlertConfig>, NoParams> {
  const GetAlertConfigs(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, List<AlertConfig>>> call(NoParams params) {
    return repository.getAlertConfigs();
  }
}
