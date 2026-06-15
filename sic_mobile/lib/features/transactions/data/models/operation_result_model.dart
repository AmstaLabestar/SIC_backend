import '../../domain/entities/operation_result.dart';

class OperationResultModel extends OperationResult {
  const OperationResultModel({
    required super.transactionId,
    required super.amount,
    required super.status,
    required super.createdAt,
    super.commissionSic,
    super.message,
  });

  factory OperationResultModel.fromJson(Map<String, dynamic> json) {
    return OperationResultModel(
      transactionId: json['transaction_id']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      commissionSic:
          json['commission_sic'] == null ? null : _toDouble(json['commission_sic']),
      message: json['message']?.toString(),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
