import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/balance_update/domain/entities/balance_update.dart';
import 'package:sic_mobile/features/balance_update/domain/repositories/balance_repository.dart';
import 'package:sic_mobile/features/balance_update/domain/usecases/update_balance.dart';

void main() {
  test('UpdateBalance transmet puceId/seuil/pinToken au repo', () async {
    final repository = _FakeBalanceRepository();
    final usecase = UpdateBalance(repository);

    final result = await usecase(
      const UpdateBalanceParams(
        puceId: 'puce-1',
        newBalance: 320000,
        pinToken: 'token-123',
      ),
    );

    expect(result.isRight(), isTrue);
    expect(repository.lastPuceId, 'puce-1');
    expect(repository.lastNewBalance, 320000);
    expect(repository.lastPinToken, 'token-123');
  });

  test('UpdateBalance propage la Failure', () async {
    final repository = _FakeBalanceRepository(
      failure: const ServerFailure('Server error', 500),
    );
    final usecase = UpdateBalance(repository);

    final result = await usecase(
      const UpdateBalanceParams(
        puceId: 'puce-1',
        newBalance: 320000,
        pinToken: null,
      ),
    );

    expect(result, const Left<Failure, BalanceUpdate>(
      ServerFailure('Server error', 500),
    ));
  });
}

class _FakeBalanceRepository implements BalanceRepository {
  _FakeBalanceRepository({this.failure});

  final Failure? failure;
  String? lastPuceId;
  double? lastNewBalance;
  String? lastPinToken;

  @override
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String puceId,
    required double newBalance,
    required String? pinToken,
  }) async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    lastPuceId = puceId;
    lastNewBalance = newBalance;
    lastPinToken = pinToken;

    return Right(
      BalanceUpdate(
        puceId: puceId,
        newBalance: newBalance,
        updatedAt: DateTime(2026, 1, 15),
      ),
    );
  }
}
