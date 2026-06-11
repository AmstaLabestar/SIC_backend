import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/dashboard/data/models/agent_summary_model.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:sic_mobile/features/dashboard/domain/usecases/refresh_balance.dart';

void main() {
  test('should return Unit when repository call is successful', () async {
    final repository = _FakeDashboardRepository();
    final usecase = RefreshBalance(repository);

    final result = await usecase(
      const RefreshBalanceParams(operatorCode: 'OM'),
    );

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('should pass selected operator code to repository', () async {
    final repository = _FakeDashboardRepository();
    final usecase = RefreshBalance(repository);

    await usecase(const RefreshBalanceParams(operatorCode: 'MOOV'));

    expect(repository.refreshedOperatorCode, 'MOOV');
  });

  test('should return Failure when repository call fails', () async {
    final repository = _FakeDashboardRepository(
      failure: const NetworkFailure(),
    );
    final usecase = RefreshBalance(repository);

    final result = await usecase(
      const RefreshBalanceParams(operatorCode: 'OM'),
    );

    expect(result, const Left<Failure, Unit>(NetworkFailure()));
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.failure});

  final Failure? failure;
  String? refreshedOperatorCode;

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    return Right(AgentSummaryModel.mock());
  }

  @override
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode) async {
    refreshedOperatorCode = operatorCode;

    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    return const Right(unit);
  }
}
