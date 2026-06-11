import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sim_card.dart';
import '../repositories/sim_repository.dart';

class ToggleSim implements UseCase<SimCard, ToggleSimParams> {
  const ToggleSim(this.repository);

  final SimRepository repository;

  @override
  Future<Either<Failure, SimCard>> call(ToggleSimParams params) {
    return repository.toggleSim(id: params.id, isActive: params.isActive);
  }
}

class ToggleSimParams extends Equatable {
  const ToggleSimParams({required this.id, required this.isActive});

  final String id;
  final bool isActive;

  @override
  List<Object?> get props => [id, isActive];
}
