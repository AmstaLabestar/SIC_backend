import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/dashboard/data/models/agent_summary_model.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:sic_mobile/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Repository factice : evite tout appel reseau dans les tests.
class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
    return Right(AgentSummaryModel.mock());
  }

  @override
  Future<Either<Failure, Unit>> refreshBalance(String operatorCode) async {
    return const Right(unit);
  }
}

void main() {
  test('should load mocked dashboard summary through provider chain', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final summary = await container.read(dashboardNotifierProvider.future);

    expect(summary, isA<AgentSummary>());
    expect(summary.agentCode, 'AGT-0042');
    expect(summary.totalBalance, 485000);
  });

  test('should default selected benefit period to today', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final selectedPeriod = container.read(selectedBenefitPeriodProvider);

    expect(selectedPeriod, DashboardBenefitPeriod.today);
  });
}
