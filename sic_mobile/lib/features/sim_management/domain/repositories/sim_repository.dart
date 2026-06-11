import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/sim_card.dart';

abstract class SimRepository {
  Future<Either<Failure, List<SimCard>>> getSims();

  Future<Either<Failure, SimCard>> addSim({
    required String operatorCode,
    required String phoneNumber,
  });

  Future<Either<Failure, SimCard>> toggleSim({
    required String id,
    required bool isActive,
  });

  Future<Either<Failure, SimCard>> updateSimThreshold({
    required String id,
    required double threshold,
  });
}
