import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/alert_config.dart';
import '../repositories/alert_repository.dart';

class UpdateAlertConfig implements UseCase<AlertConfig, UpdateAlertConfigParams> {
  const UpdateAlertConfig(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, AlertConfig>> call(UpdateAlertConfigParams params) {
    return repository.updateAlertConfig(
      id: params.id,
      threshold: params.threshold,
      isEnabled: params.isEnabled,
    );
  }
}

class UpdateAlertConfigParams extends Equatable {
  const UpdateAlertConfigParams({
    required this.id,
    required this.threshold,
    required this.isEnabled,
  });

  final String id;
  final double threshold;
  final bool isEnabled;

  @override
  List<Object?> get props => [id, threshold, isEnabled];
}
