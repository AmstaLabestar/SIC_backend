import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/agent_summary.dart';

abstract class DashboardRepository {
  Future<Either<Failure, AgentSummary>> getDashboardSummary();

  Future<Either<Failure, Unit>> refreshBalance(String operatorCode);

  /// Modifie une puce (operateur, numero, statut Mobile Money).
  Future<Either<Failure, Unit>> updatePuce({
    required String id,
    required String operatorCode,
    required String phoneNumber,
    required bool isActive,
  });

  /// Supprime une puce.
  Future<Either<Failure, Unit>> deletePuce(String id);

  /// Ajoute une nouvelle puce.
  Future<Either<Failure, Unit>> createPuce({
    required String operatorCode,
    required String phoneNumber,
  });
}
