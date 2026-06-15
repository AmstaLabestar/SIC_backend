import 'package:equatable/equatable.dart';

/// Type d'operation, derive du champ backend `type` (DEPOT / RETRAIT / SWAP).
enum TransactionKind { deposit, withdrawal, transfer, other }

/// Une transaction de l'agent (element d'historique).
class AgentTransaction extends Equatable {
  const AgentTransaction({
    required this.id,
    required this.kind,
    required this.status,
    required this.amount,
    required this.commissionSic,
    required this.createdAt,
    this.operatorCode,
    this.operatorName,
    this.phoneNumber,
    this.isCompensated = false,
  });

  final String id;
  final TransactionKind kind;

  /// Statut backend brut (ex: PENDING, SUCCESS, FAILED, EXPIRED).
  final String status;
  final double amount;
  final double commissionSic;
  final DateTime createdAt;

  /// Operateur cible (depot/retrait). Nul pour un transfert entre puces.
  final String? operatorCode;
  final String? operatorName;
  final String? phoneNumber;
  final bool isCompensated;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isSuccess => status.toUpperCase() == 'SUCCESS';
  bool get isFailed =>
      status.toUpperCase() == 'FAILED' || status.toUpperCase() == 'EXPIRED';

  @override
  List<Object?> get props => [
        id,
        kind,
        status,
        amount,
        commissionSic,
        createdAt,
        operatorCode,
        operatorName,
        phoneNumber,
        isCompensated,
      ];
}
