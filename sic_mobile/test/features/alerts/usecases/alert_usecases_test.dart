import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/usecases/usecase.dart';
import 'package:sic_mobile/features/alerts/domain/entities/alert_config.dart';
import 'package:sic_mobile/features/alerts/domain/repositories/alert_repository.dart';
import 'package:sic_mobile/features/alerts/domain/usecases/get_alert_configs.dart';
import 'package:sic_mobile/features/alerts/domain/usecases/save_alert_config.dart';

void main() {
  test('should return alert configs when repository call is successful', () async {
    final repository = _FakeAlertRepository();
    final usecase = GetAlertConfigs(repository);

    final result = await usecase(const NoParams());

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('should save alert config when repository call is successful', () async {
    final repository = _FakeAlertRepository();
    final usecase = SaveAlertConfig(repository);
    final config = _alertConfig.copyWith(threshold: 75000);

    final result = await usecase(config);

    expect(result.isRight(), isTrue);
    expect(repository.lastSavedThreshold, 75000);
  });

  test('should return Failure when repository call fails', () async {
    final repository = _FakeAlertRepository(
      failure: const CacheFailure('Cache error'),
    );
    final usecase = GetAlertConfigs(repository);

    final result = await usecase(const NoParams());

    expect(result, const Left<Failure, List<AlertConfig>>(
      CacheFailure('Cache error'),
    ));
  });
}

final _alertConfig = AlertConfig(
  operatorCode: 'OM',
  operatorName: 'Orange Money',
  isEnabled: true,
  threshold: 50000,
  lastUpdated: DateTime(2024, 1, 15),
);

class _FakeAlertRepository implements AlertRepository {
  _FakeAlertRepository({this.failure});

  final Failure? failure;
  double? lastSavedThreshold;

  @override
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs() async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    return Right([_alertConfig]);
  }

  @override
  Future<Either<Failure, AlertConfig>> saveAlertConfig(
    AlertConfig config,
  ) async {
    lastSavedThreshold = config.threshold;
    return Right(config);
  }
}
