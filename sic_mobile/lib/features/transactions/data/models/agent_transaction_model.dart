import '../../../../core/network/operator_mapping.dart';
import '../../domain/entities/agent_transaction.dart';

class AgentTransactionModel extends AgentTransaction {
  const AgentTransactionModel({
    required super.id,
    required super.kind,
    required super.status,
    required super.amount,
    required super.commissionSic,
    required super.agentBenefit,
    required super.createdAt,
    super.operatorCode,
    super.operatorName,
    super.phoneNumber,
    super.isCompensated,
  });

  factory AgentTransactionModel.fromJson(Map<String, dynamic> json) {
    final backendOperator = json['target_operator']?.toString();
    String? code;
    String? name;
    if (backendOperator != null && backendOperator.isNotEmpty) {
      final mapped = OperatorMapping.fromBackend(backendOperator);
      code = mapped.code;
      name = mapped.name;
    }

    return AgentTransactionModel(
      id: json['id']?.toString() ?? '',
      kind: _kindFromBackend(json['type']?.toString()),
      status: json['status']?.toString() ?? 'PENDING',
      amount: _toDouble(json['amount']),
      commissionSic: _toDouble(json['commission_sic']),
      agentBenefit: _toDouble(json['agent_benefit']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      operatorCode: code,
      operatorName: name,
      phoneNumber: json['target_phone_number']?.toString(),
      isCompensated: json['is_compensated'] as bool? ?? false,
    );
  }

  static TransactionKind _kindFromBackend(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOT':
        return TransactionKind.deposit;
      case 'RETRAIT':
        return TransactionKind.withdrawal;
      case 'SWAP':
        return TransactionKind.transfer;
      default:
        return TransactionKind.other;
    }
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
