import 'package:equatable/equatable.dart';

/// Resultat d'une operation (depot / retrait / transfert) renvoye par le backend.
class OperationResult extends Equatable {
  const OperationResult({
    required this.transactionId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.commissionSic,
    this.agentBenefit,
    this.message,
  });

  final String transactionId;
  final double amount;

  /// Statut backend (typiquement PENDING en attendant le webhook CinetPay).
  final String status;
  final DateTime createdAt;

  /// Absents pour un transfert (conversion entre puces).
  final double? commissionSic;
  final double? agentBenefit;
  final String? message;

  @override
  List<Object?> get props => [
        transactionId,
        amount,
        status,
        createdAt,
        commissionSic,
        agentBenefit,
        message,
      ];
}
