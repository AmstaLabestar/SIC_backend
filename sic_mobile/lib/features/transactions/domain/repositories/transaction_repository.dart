import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/agent_transaction.dart';
import '../entities/operation_result.dart';

abstract class TransactionRepository {
  /// Historique des transactions de l'agent (`GET /transactions/`).
  Future<Either<Failure, List<AgentTransaction>>> getTransactions();

  /// Depot : `POST /transactions/deposit/`.
  Future<Either<Failure, OperationResult>> deposit({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
  });

  /// Retrait : `POST /transactions/withdraw/`.
  Future<Either<Failure, OperationResult>> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
  });

  /// Transfert (conversion entre puces) : `POST /transactions/conversion/`.
  Future<Either<Failure, OperationResult>> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
  });
}
