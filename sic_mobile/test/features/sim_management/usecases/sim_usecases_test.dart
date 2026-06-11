import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/usecases/usecase.dart';
import 'package:sic_mobile/features/sim_management/domain/entities/sim_card.dart';
import 'package:sic_mobile/features/sim_management/domain/repositories/sim_repository.dart';
import 'package:sic_mobile/features/sim_management/domain/usecases/add_sim.dart';
import 'package:sic_mobile/features/sim_management/domain/usecases/get_sims.dart';
import 'package:sic_mobile/features/sim_management/domain/usecases/toggle_sim.dart';
import 'package:sic_mobile/features/sim_management/domain/usecases/update_sim_threshold.dart';

void main() {
  test('should return sims when GetSims repository call is successful', () async {
    final repository = _FakeSimRepository();
    final usecase = GetSims(repository);

    final result = await usecase(const NoParams());

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('should add sim when AddSim repository call is successful', () async {
    final repository = _FakeSimRepository();
    final usecase = AddSim(repository);

    final result = await usecase(
      const AddSimParams(operatorCode: 'MOOV', phoneNumber: '0501234567'),
    );

    expect(result.isRight(), isTrue);
    expect(repository.lastAddedOperatorCode, 'MOOV');
  });

  test('should toggle sim when ToggleSim repository call is successful', () async {
    final repository = _FakeSimRepository();
    final usecase = ToggleSim(repository);

    final result = await usecase(
      const ToggleSimParams(id: 'sim_001', isActive: false),
    );

    expect(result.isRight(), isTrue);
    expect(repository.lastToggleValue, isFalse);
  });

  test(
    'should update threshold when UpdateSimThreshold repository call succeeds',
    () async {
      final repository = _FakeSimRepository();
      final usecase = UpdateSimThreshold(repository);

      final result = await usecase(
        const UpdateSimThresholdParams(id: 'sim_001', threshold: 75000),
      );

      expect(result.isRight(), isTrue);
      expect(repository.lastThreshold, 75000);
    },
  );

  test('should return Failure when repository call fails', () async {
    final repository = _FakeSimRepository(
      failure: const ServerFailure('Server error', 500),
    );
    final usecase = GetSims(repository);

    final result = await usecase(const NoParams());

    expect(result, const Left<Failure, List<SimCard>>(
      ServerFailure('Server error', 500),
    ));
  });
}

class _FakeSimRepository implements SimRepository {
  _FakeSimRepository({this.failure});

  final Failure? failure;
  String? lastAddedOperatorCode;
  bool? lastToggleValue;
  double? lastThreshold;

  final SimCard _sim = SimCard(
    id: 'sim_001',
    operatorCode: 'OM',
    operatorName: 'Orange Money',
    phoneNumber: '0701234567',
    balance: 250000,
    isActive: true,
    alertThreshold: 50000,
    addedAt: DateTime(2024, 1, 10),
  );

  @override
  Future<Either<Failure, List<SimCard>>> getSims() async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    return Right([_sim]);
  }

  @override
  Future<Either<Failure, SimCard>> addSim({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    lastAddedOperatorCode = operatorCode;
    return Right(_sim.copyWith(
      operatorCode: operatorCode,
      phoneNumber: phoneNumber,
    ));
  }

  @override
  Future<Either<Failure, SimCard>> toggleSim({
    required String id,
    required bool isActive,
  }) async {
    lastToggleValue = isActive;
    return Right(_sim.copyWith(id: id, isActive: isActive));
  }

  @override
  Future<Either<Failure, SimCard>> updateSimThreshold({
    required String id,
    required double threshold,
  }) async {
    lastThreshold = threshold;
    return Right(_sim.copyWith(id: id, alertThreshold: threshold));
  }
}
