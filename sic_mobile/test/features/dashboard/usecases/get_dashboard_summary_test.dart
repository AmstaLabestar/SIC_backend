import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/usecases/usecase.dart';
import 'package:sic_mobile/features/dashboard/data/models/agent_summary_model.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:sic_mobile/features/dashboard/domain/usecases/get_dashboard_summary.dart';

void main() {
  test('should return AgentSummary when repository call is successful', () async {
    const repository = _FakeDashboardRepository();
    const usecase = GetDashboardSummary(repository);

    final result = await usecase(const NoParams());

    expect(result.isRight(), isTrue);
    expect(result.getOrElse(() => throw AssertionError()), isA<AgentSummary>());
  });

  test('should return Failure when repository call fails', () async {
    const repository = _FakeDashboardRepository(
      failure: ServerFailure('Server error', 500),
    );
    const usecase = GetDashboardSummary(repository);

    final result = await usecase(const NoParams());

    expect(result, const Left<Failure, AgentSummary>(
      ServerFailure('Server error', 500),
    ));
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  const _FakeDashboardRepository({this.failure});

  final Failure? failure;

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    return Right(AgentSummaryModel.mock());
  }

  @override
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> updatePuce({
    required String id,
    required String operatorCode,
    required String phoneNumber,
    required bool isActive,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> deletePuce(String id) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> createPuce({
    required String operatorCode,
    required String phoneNumber,
  }) async =>
      const Right(unit);
}
