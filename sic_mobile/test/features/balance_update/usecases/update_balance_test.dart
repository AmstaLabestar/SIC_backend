import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/balance_update/domain/entities/balance_update.dart';
import 'package:sic_mobile/features/balance_update/domain/repositories/balance_repository.dart';
import 'package:sic_mobile/features/balance_update/domain/usecases/update_balance.dart';

void main() {
  test('should update balance when repository call is successful', () async {
    final repository = _FakeBalanceRepository();
    final usecase = UpdateBalance(repository);

    final result = await usecase(
      const UpdateBalanceParams(
        operatorCode: 'OM',
        previousBalance: 250000,
        newBalance: 320000,
      ),
    );

    expect(result.isRight(), isTrue);
    expect(repository.lastNewBalance, 320000);
  });

  test('should return Failure when repository call fails', () async {
    final repository = _FakeBalanceRepository(
      failure: const ServerFailure('Server error', 500),
    );
    final usecase = UpdateBalance(repository);

    final result = await usecase(
      const UpdateBalanceParams(
        operatorCode: 'OM',
        previousBalance: 250000,
        newBalance: 320000,
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
  double? lastNewBalance;

  @override
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String operatorCode,
    required double previousBalance,
    required double newBalance,
  }) async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    lastNewBalance = newBalance;

    return Right(
      BalanceUpdate(
        operatorCode: operatorCode,
        previousBalance: previousBalance,
        newBalance: newBalance,
        updatedAt: DateTime(2024, 1, 15),
      ),
    );
  }

  @override
  Future<Either<Failure, List<BalanceUpdate>>> getBalanceHistory(
    String operatorCode,
  ) async {
    return const Right([]);
  }
}
