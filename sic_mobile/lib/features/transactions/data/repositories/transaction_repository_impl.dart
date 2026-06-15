import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_failure.dart';
import '../../domain/entities/agent_transaction.dart';
import '../../domain/entities/operation_result.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl(this._datasource);

  final TransactionRemoteDatasource _datasource;

  @override
  Future<Either<Failure, List<AgentTransaction>>> getTransactions() async {
    try {
      return Right(await _datasource.getTransactions());
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, OperationResult>> deposit({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) async {
    try {
      return Right(await _datasource.deposit(
        amount: amount,
        operatorCode: operatorCode,
        phoneNumber: phoneNumber,
        pinToken: pinToken,
      ));
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, OperationResult>> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) async {
    try {
      return Right(await _datasource.withdraw(
        amount: amount,
        operatorCode: operatorCode,
        phoneNumber: phoneNumber,
        pinToken: pinToken,
      ));
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, OperationResult>> transfer({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) async {
    try {
      return Right(await _datasource.transfer(
        amount: amount,
        operatorCode: operatorCode,
        phoneNumber: phoneNumber,
        pinToken: pinToken,
      ));
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }

  @override
  Future<Either<Failure, OperationResult>> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
    String? pinToken,
  }) async {
    try {
      return Right(await _datasource.convert(
        amount: amount,
        sourcePuceId: sourcePuceId,
        targetPuceId: targetPuceId,
        pinToken: pinToken,
      ));
    } catch (error) {
      return Left(mapDioErrorToFailure(error));
    }
  }
}
