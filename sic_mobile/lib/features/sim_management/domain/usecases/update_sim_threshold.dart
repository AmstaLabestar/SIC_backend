import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sim_card.dart';
import '../repositories/sim_repository.dart';

class UpdateSimThreshold
    implements UseCase<SimCard, UpdateSimThresholdParams> {
  const UpdateSimThreshold(this.repository);

  final SimRepository repository;

  @override
  Future<Either<Failure, SimCard>> call(UpdateSimThresholdParams params) {
    return repository.updateSimThreshold(
      id: params.id,
      threshold: params.threshold,
    );
  }
}

class UpdateSimThresholdParams extends Equatable {
  const UpdateSimThresholdParams({
    required this.id,
    required this.threshold,
  });

  final String id;
  final double threshold;

  @override
  List<Object?> get props => [id, threshold];
}
