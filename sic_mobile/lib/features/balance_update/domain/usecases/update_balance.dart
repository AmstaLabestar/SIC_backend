import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/balance_update.dart';
import '../repositories/balance_repository.dart';

class UpdateBalance implements UseCase<BalanceUpdate, UpdateBalanceParams> {
  const UpdateBalance(this.repository);

  final BalanceRepository repository;

  @override
  Future<Either<Failure, BalanceUpdate>> call(UpdateBalanceParams params) {
    return repository.updateBalance(
      operatorCode: params.operatorCode,
      previousBalance: params.previousBalance,
      newBalance: params.newBalance,
    );
  }
}

class UpdateBalanceParams extends Equatable {
  const UpdateBalanceParams({
    required this.operatorCode,
    required this.previousBalance,
    required this.newBalance,
  });

  final String operatorCode;
  final double previousBalance;
  final double newBalance;

  @override
  List<Object?> get props => [operatorCode, previousBalance, newBalance];
}
