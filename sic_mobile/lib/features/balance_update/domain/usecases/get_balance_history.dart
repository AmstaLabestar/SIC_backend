import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/balance_update.dart';
import '../repositories/balance_repository.dart';

class GetBalanceHistory
    implements UseCase<List<BalanceUpdate>, GetBalanceHistoryParams> {
  const GetBalanceHistory(this.repository);

  final BalanceRepository repository;

  @override
  Future<Either<Failure, List<BalanceUpdate>>> call(
    GetBalanceHistoryParams params,
  ) {
    return repository.getBalanceHistory(params.operatorCode);
  }
}

class GetBalanceHistoryParams extends Equatable {
  const GetBalanceHistoryParams({required this.operatorCode});

  final String operatorCode;

  @override
  List<Object?> get props => [operatorCode];
}
