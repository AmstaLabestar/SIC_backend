import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/agent_transaction.dart';
import '../entities/operation_result.dart';

abstract class TransactionRepository {
  /// Historique des transactions de l'agent (`GET /transactions/`).
  Future<Either<Failure, List<AgentTransaction>>> getTransactions();

  /// Depot : `POST /transactions/deposit/`. [pinToken] (obligatoire des qu'un
  /// PIN est configure) est transmis en en-tete `X-PIN-TOKEN`.
  Future<Either<Failure, OperationResult>> deposit({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  });

  /// Retrait : `POST /transactions/withdraw/`. Voir [deposit] pour [pinToken].
  Future<Either<Failure, OperationResult>> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  });

  /// Envoi P2P vers un numero : `POST /transactions/transfer/`.
  /// Voir [deposit] pour [pinToken].
  Future<Either<Failure, OperationResult>> transfer({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  });

  /// Conversion / reequilibrage entre puces de l'agent :
  /// `POST /transactions/conversion/`. Voir [deposit] pour [pinToken].
  Future<Either<Failure, OperationResult>> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
    String? pinToken,
  });
}
