import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/core/usecases/usecase.dart';
import 'package:sic_mobile/features/alerts/domain/entities/alert_config.dart';
import 'package:sic_mobile/features/alerts/domain/repositories/alert_repository.dart';
import 'package:sic_mobile/features/alerts/domain/usecases/get_alert_configs.dart';
import 'package:sic_mobile/features/alerts/domain/usecases/update_alert_config.dart';

void main() {
  test('GetAlertConfigs renvoie les alertes en cas de succes', () async {
    final repository = _FakeAlertRepository();
    final usecase = GetAlertConfigs(repository);

    final result = await usecase(const NoParams());

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('UpdateAlertConfig transmet id/seuil/activation au repo', () async {
    final repository = _FakeAlertRepository();
    final usecase = UpdateAlertConfig(repository);

    final result = await usecase(const UpdateAlertConfigParams(
      id: 'cfg-1',
      threshold: 75000,
      isEnabled: false,
    ));

    expect(result.isRight(), isTrue);
    expect(repository.lastId, 'cfg-1');
    expect(repository.lastThreshold, 75000);
    expect(repository.lastIsEnabled, isFalse);
  });

  test('GetAlertConfigs propage la Failure', () async {
    final repository = _FakeAlertRepository(
      failure: const ServerFailure('Erreur reseau'),
    );
    final usecase = GetAlertConfigs(repository);

    final result = await usecase(const NoParams());

    expect(result, const Left<Failure, List<AlertConfig>>(
      ServerFailure('Erreur reseau'),
    ));
  });
}

final _alertConfig = AlertConfig(
  id: 'cfg-1',
  puceId: 'puce-1',
  operatorCode: 'OM',
  operatorName: 'Orange Money',
  phoneNumber: '+22670000001',
  isEnabled: true,
  threshold: 50000,
  lastUpdated: DateTime(2026, 1, 15),
);

class _FakeAlertRepository implements AlertRepository {
  _FakeAlertRepository({this.failure});

  final Failure? failure;
  String? lastId;
  double? lastThreshold;
  bool? lastIsEnabled;

  @override
  Future<Either<Failure, List<AlertConfig>>> getAlertConfigs() async {
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right([_alertConfig]);
  }

  @override
  Future<Either<Failure, AlertConfig>> updateAlertConfig({
    required String id,
    required double threshold,
    required bool isEnabled,
  }) async {
    lastId = id;
    lastThreshold = threshold;
    lastIsEnabled = isEnabled;
    return Right(_alertConfig.copyWith(
      threshold: threshold,
      isEnabled: isEnabled,
    ));
  }
}
