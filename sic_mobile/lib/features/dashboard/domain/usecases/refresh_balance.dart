import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/dashboard_repository.dart';

class RefreshBalance implements UseCase<Unit, RefreshBalanceParams> {
  const RefreshBalance(this.repository);

  final DashboardRepository repository;

  @override
  Future<Either<Failure, Unit>> call(RefreshBalanceParams params) {
    return repository.refreshBalance(params.operatorCode);
  }
}

class RefreshBalanceParams extends Equatable {
  const RefreshBalanceParams({required this.operatorCode});

  final String operatorCode;

  @override
  List<Object?> get props => [operatorCode];
}
