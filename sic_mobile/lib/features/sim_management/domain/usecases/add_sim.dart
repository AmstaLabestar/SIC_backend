import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sim_card.dart';
import '../repositories/sim_repository.dart';

class AddSim implements UseCase<SimCard, AddSimParams> {
  const AddSim(this.repository);

  final SimRepository repository;

  @override
  Future<Either<Failure, SimCard>> call(AddSimParams params) {
    return repository.addSim(
      operatorCode: params.operatorCode,
      phoneNumber: params.phoneNumber,
    );
  }
}

class AddSimParams extends Equatable {
  const AddSimParams({
    required this.operatorCode,
    required this.phoneNumber,
  });

  final String operatorCode;
  final String phoneNumber;

  @override
  List<Object?> get props => [operatorCode, phoneNumber];
}
