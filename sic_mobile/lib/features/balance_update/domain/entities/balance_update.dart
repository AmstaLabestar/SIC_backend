import 'package:equatable/equatable.dart';

/// Resultat d'une reconciliation manuelle du solde d'une puce.
class BalanceUpdate extends Equatable {
  const BalanceUpdate({
    required this.puceId,
    required this.newBalance,
    required this.updatedAt,
  });

  final String puceId;
  final double newBalance;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [puceId, newBalance, updatedAt];
}
