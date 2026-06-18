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
      puceId: params.puceId,
      newBalance: params.newBalance,
      pinToken: params.pinToken,
    );
  }
}

class UpdateBalanceParams extends Equatable {
  const UpdateBalanceParams({
    required this.puceId,
    required this.newBalance,
    required this.pinToken,
  });

  final String puceId;
  final double newBalance;
  final String? pinToken;

  @override
  List<Object?> get props => [puceId, newBalance, pinToken];
}
