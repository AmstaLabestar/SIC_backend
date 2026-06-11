import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/sim_card.dart';
import '../repositories/sim_repository.dart';

class GetSims implements UseCase<List<SimCard>, NoParams> {
  const GetSims(this.repository);

  final SimRepository repository;

  @override
  Future<Either<Failure, List<SimCard>>> call(NoParams params) {
    return repository.getSims();
  }
}
