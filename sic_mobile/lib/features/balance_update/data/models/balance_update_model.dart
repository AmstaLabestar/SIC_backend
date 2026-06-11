import '../../domain/entities/balance_update.dart';

class BalanceUpdateModel extends BalanceUpdate {
  const BalanceUpdateModel({
    required super.operatorCode,
    required super.previousBalance,
    required super.newBalance,
    required super.updatedAt,
  });

  factory BalanceUpdateModel.fromJson(Map<String, dynamic> json) {
    return BalanceUpdateModel(
      operatorCode: json['operator_code'] as String,
      previousBalance: (json['previous_balance'] as num).toDouble(),
      newBalance: (json['balance'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operator_code': operatorCode,
      'previous_balance': previousBalance,
      'balance': newBalance,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
