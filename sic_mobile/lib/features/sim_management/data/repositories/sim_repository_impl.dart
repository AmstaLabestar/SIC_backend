import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/sim_card.dart';
import '../../domain/repositories/sim_repository.dart';
import '../datasources/sim_local_datasource.dart';

class SimRepositoryImpl implements SimRepository {
  const SimRepositoryImpl(this.localDatasource);

  final SimLocalDatasource localDatasource;

  @override
  Future<Either<Failure, List<SimCard>>> getSims() async {
    try {
      final sims = await localDatasource.getSims();
      return Right(sims);
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de charger les puces.'));
    }
  }

  @override
  Future<Either<Failure, SimCard>> addSim({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    try {
      final sim = await localDatasource.addSim(
        operatorCode: operatorCode,
        phoneNumber: phoneNumber,
      );
      return Right(sim);
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible d ajouter cette puce.'));
    }
  }

  @override
  Future<Either<Failure, SimCard>> toggleSim({
    required String id,
    required bool isActive,
  }) async {
    try {
      final sim = await localDatasource.toggleSim(id: id, isActive: isActive);
      return Right(sim);
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de modifier cette puce.'));
    }
  }

  @override
  Future<Either<Failure, SimCard>> updateSimThreshold({
    required String id,
    required double threshold,
  }) async {
    try {
      final sim = await localDatasource.updateSimThreshold(
        id: id,
        threshold: threshold,
      );
      return Right(sim);
    } on ServerException catch (error) {
      return Left(ServerFailure(error.message, error.statusCode));
    } catch (_) {
      return const Left(ServerFailure('Impossible de modifier le seuil.'));
    }
  }
}
