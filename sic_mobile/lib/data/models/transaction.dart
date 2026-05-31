/// Transaction Model for SIC Mobile
class Transaction {
  final String id;
  final String? agentName;
  final String type; // DEPOT, RETRAIT, TRANSFERT, SWAP
  final String status; // PENDING, COMPLETED, FAILED
  final String targetOperator;
  final String? targetPhoneNumber;
  final double amount;
  final double commissionSic;
  final double agentBenefit;
  final bool isCompensated;
  final List<CompensationDetail>? compensationDetails;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    this.agentName,
    required this.type,
    required this.status,
    required this.targetOperator,
    this.targetPhoneNumber,
    required this.amount,
    this.commissionSic = 0.0,
    this.agentBenefit = 0.0,
    this.isCompensated = false,
    this.compensationDetails,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get type label
  String get typeLabel {
    switch (type.toUpperCase()) {
      case 'DEPOT':
        return 'Dépôt';
      case 'RETRAIT':
        return 'Retrait';
      case 'TRANSFERT':
        return 'Transfert';
      case 'SWAP':
        return 'Conversion';
      default:
        return type;
    }
  }

  /// Get status label
  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'En attente';
      case 'COMPLETED':
        return 'Complété';
      case 'FAILED':
        return 'Échoué';
      case 'SUCCESS':
        return 'Succès';
      case 'REFUNDED':
        return 'Remboursé';
      default:
        return status;
    }
  }

  /// Check if pending
  bool get isPending => status.toUpperCase() == 'PENDING';

  /// Check if completed
  bool get isCompleted => status.toUpperCase() == 'COMPLETED' || status.toUpperCase() == 'SUCCESS';

  /// Check if failed
  bool get isFailed => status.toUpperCase() == 'FAILED';

  /// Check if is deposit
  bool get isDeposit => type.toUpperCase() == 'DEPOT';

  /// Check if is withdrawal
  bool get isWithdrawal => type.toUpperCase() == 'RETRAIT';

  /// Check if is swap/conversion
  bool get isSwap => type.toUpperCase() == 'SWAP';

  /// Get amount with sign (+ for incoming, - for outgoing)
  double get signedAmount {
    return isDeposit ? amount : -amount;
  }

  /// Create from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      agentName: json['agent_name'],
      type: json['type'] ?? '',
      status: json['status'] ?? 'PENDING',
      targetOperator: json['target_operator'] ?? '',
      targetPhoneNumber: json['target_phone_number'],
      amount: _parseDouble(json['amount']),
      commissionSic: _parseDouble(json['commission_sic']),
      agentBenefit: _parseDouble(json['agent_benefit']),
      isCompensated: json['is_compensated'] ?? false,
      compensationDetails: json['compensation_details'] != null
          ? (json['compensation_details'] as List)
              .map((d) => CompensationDetail.fromJson(d))
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agent_name': agentName,
      'type': type,
      'status': status,
      'target_operator': targetOperator,
      'target_phone_number': targetPhoneNumber,
      'amount': amount,
      'commission_sic': commissionSic,
      'agent_benefit': agentBenefit,
      'is_compensated': isCompensated,
      'compensation_details': compensationDetails?.map((d) => d.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Transaction(id: $id, type: $type, amount: $amount, status: $status)';
  }
}

/// Compensation Detail Model
class CompensationDetail {
  final String id;
  final String? puceOperator;
  final String? pucePhone;
  final double amountDeducted;
  final String status;
  final String? cinetpayRef;
  final DateTime createdAt;

  CompensationDetail({
    required this.id,
    this.puceOperator,
    this.pucePhone,
    required this.amountDeducted,
    required this.status,
    this.cinetpayRef,
    required this.createdAt,
  });

  /// Create from JSON
  factory CompensationDetail.fromJson(Map<String, dynamic> json) {
    return CompensationDetail(
      id: json['id']?.toString() ?? '',
      puceOperator: json['puce_operator'],
      pucePhone: json['puce_phone'],
      amountDeducted: _parseDouble(json['amount_deducted']),
      status: json['status'] ?? 'PENDING',
      cinetpayRef: json['cinetpay_ref'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'puce_operator': puceOperator,
      'puce_phone': pucePhone,
      'amount_deducted': amountDeducted,
      'status': status,
      'cinetpay_ref': cinetpayRef,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Helper to parse double from dynamic
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}