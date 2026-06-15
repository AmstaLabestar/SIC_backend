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
  _FakeDashboardRepository({this.failure});

  /// Si non nul, les mutations de puces echouent avec cette erreur.
  final Failure? failure;

  final List<String> calls = [];
  String? lastUpdatedId;
  String? lastUpdatedOperator;
  String? lastDeletedId;
  String? lastCreatedOperator;

  @override
  Future<Either<Failure, AgentSummary>> getDashboardSummary() async {
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
  }) async {
    calls.add('update');
    lastUpdatedId = id;
    lastUpdatedOperator = operatorCode;
    final failure = this.failure;
    return failure != null ? Left(failure) : const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deletePuce(String id) async {
    calls.add('delete');
    lastDeletedId = id;
    final failure = this.failure;
    return failure != null ? Left(failure) : const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> createPuce({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    calls.add('create');
    lastCreatedOperator = operatorCode;
    final failure = this.failure;
    return failure != null ? Left(failure) : const Right(unit);
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

    final selectedPeriod = container.read(selectedPeriodProvider);

    expect(selectedPeriod, DashboardPeriod.today);
  });

  test('updateSim envoie l\'id au repo et retourne null en cas de succes',
      () async {
    final repo = _FakeDashboardRepository();
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardNotifierProvider.future);

    final error = await container
        .read(dashboardNotifierProvider.notifier)
        .updateSim(
          id: 'puce-123',
          operatorCode: 'OM',
          phoneNumber: '0701234567',
          isActive: false,
        );

    expect(error, isNull);
    expect(repo.calls, contains('update'));
    expect(repo.lastUpdatedId, 'puce-123');
    expect(repo.lastUpdatedOperator, 'OM');
  });

  test('removeSim retourne le message d\'erreur en cas d\'echec', () async {
    final repo = _FakeDashboardRepository(
      failure: const ValidationFailure('Suppression impossible.'),
    );
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardNotifierProvider.future);

    final error = await container
        .read(dashboardNotifierProvider.notifier)
        .removeSim('puce-9');

    expect(error, 'Suppression impossible.');
    expect(repo.lastDeletedId, 'puce-9');
  });

  test('addSim appelle createPuce avec l\'operateur choisi', () async {
    final repo = _FakeDashboardRepository();
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardNotifierProvider.future);

    final error = await container
        .read(dashboardNotifierProvider.notifier)
        .addSim(operatorCode: 'MOOV', phoneNumber: '0102030405');

    expect(error, isNull);
    expect(repo.calls, contains('create'));
    expect(repo.lastCreatedOperator, 'MOOV');
  });
}
