import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/agent_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummary implements UseCase<AgentSummary, NoParams> {
  const GetDashboardSummary(this.repository);

  final DashboardRepository repository;

  @override
  Future<Either<Failure, AgentSummary>> call(NoParams params) {
    return repository.getDashboardSummary();
  }
}
