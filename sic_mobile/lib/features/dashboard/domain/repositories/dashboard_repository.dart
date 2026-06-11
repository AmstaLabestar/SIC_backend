import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/agent_summary.dart';

abstract class DashboardRepository {
  Future<Either<Failure, AgentSummary>> getDashboardSummary();

  Future<Either<Failure, Unit>> refreshBalance(String operatorCode);
}
