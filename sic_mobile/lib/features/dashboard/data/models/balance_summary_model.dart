import '../../domain/entities/balance_summary.dart';

class BalanceSummaryModel extends BalanceSummary {
  const BalanceSummaryModel({
    required super.operatorCode,
    required super.operatorName,
    required super.phoneNumber,
    required super.balance,
    required super.isLow,
    required super.alertThreshold,
    required super.lastUpdated,
    super.isActive,
    super.id,
  });

  factory BalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return BalanceSummaryModel(
      id: json['id'] as String?,
      operatorCode: json['operator_code'] as String,
      operatorName: json['operator_name'] as String,
      phoneNumber: json['phone_number'] as String,
      balance: (json['balance'] as num).toDouble(),
      isLow: json['is_low'] as bool,
      alertThreshold: (json['alert_threshold'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['last_updated'] as String).toLocal(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  factory BalanceSummaryModel.mock(String operatorCode) {
    final now = DateTime.now();

    return switch (operatorCode.toUpperCase()) {
      'OM' => BalanceSummaryModel(
          operatorCode: 'OM',
          operatorName: 'Orange Money',
          phoneNumber: '0701234234',
          balance: 250000,
          isLow: false,
          alertThreshold: 50000,
          lastUpdated: now,
        ),
      'MOOV' => BalanceSummaryModel(
          operatorCode: 'MOOV',
          operatorName: 'Moov Money',
          phoneNumber: '0601238891',
          balance: 35000,
          isLow: true,
          alertThreshold: 50000,
          lastUpdated: now.subtract(const Duration(minutes: 7)),
        ),
      'TELECEL' => BalanceSummaryModel(
          operatorCode: 'TELECEL',
          operatorName: 'Telecel Money',
          phoneNumber: '0104567890',
          balance: 200000,
          isLow: false,
          alertThreshold: 50000,
          lastUpdated: now.subtract(const Duration(minutes: 15)),
        ),
      _ => BalanceSummaryModel(
          operatorCode: operatorCode.toUpperCase(),
          operatorName: operatorCode.toUpperCase(),
          phoneNumber: '0700000000',
          balance: 0,
          isLow: true,
          alertThreshold: 50000,
          lastUpdated: now,
        ),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operator_code': operatorCode,
      'operator_name': operatorName,
      'phone_number': phoneNumber,
      'balance': balance,
      'is_low': isLow,
      'alert_threshold': alertThreshold,
      'last_updated': lastUpdated.toUtc().toIso8601String(),
      'is_active': isActive,
    };
  }
}
