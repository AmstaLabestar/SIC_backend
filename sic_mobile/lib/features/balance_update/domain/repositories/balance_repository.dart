import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/balance_update.dart';

abstract class BalanceRepository {
  /// Reconcilie le solde d'une puce (valeur absolue) cote backend.
  /// Operation sensible : un `pinToken` valide est requis si l'agent a un PIN.
  Future<Either<Failure, BalanceUpdate>> updateBalance({
    required String puceId,
    required double newBalance,
    required String? pinToken,
  });
}
