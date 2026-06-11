import '../../domain/entities/sim_card.dart';

class SimCardModel extends SimCard {
  const SimCardModel({
    required super.id,
    required super.operatorCode,
    required super.operatorName,
    required super.phoneNumber,
    required super.balance,
    required super.isActive,
    required super.alertThreshold,
    required super.addedAt,
  });

  factory SimCardModel.fromEntity(SimCard sim) {
    return SimCardModel(
      id: sim.id,
      operatorCode: sim.operatorCode,
      operatorName: sim.operatorName,
      phoneNumber: sim.phoneNumber,
      balance: sim.balance,
      isActive: sim.isActive,
      alertThreshold: sim.alertThreshold,
      addedAt: sim.addedAt,
    );
  }

  factory SimCardModel.fromJson(Map<String, dynamic> json) {
    return SimCardModel(
      id: json['id'] as String,
      operatorCode: json['operator_code'] as String,
      operatorName: json['operator_name'] as String,
      phoneNumber: json['phone_number'] as String,
      balance: (json['balance'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      alertThreshold: (json['alert_threshold'] as num).toDouble(),
      addedAt: DateTime.parse(json['added_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operator_code': operatorCode,
      'operator_name': operatorName,
      'phone_number': phoneNumber,
      'balance': balance,
      'is_active': isActive,
      'alert_threshold': alertThreshold,
      'added_at': addedAt.toUtc().toIso8601String(),
    };
  }

  SimCardModel copyModelWith({
    String? id,
    String? operatorCode,
    String? operatorName,
    String? phoneNumber,
    double? balance,
    bool? isActive,
    double? alertThreshold,
    DateTime? addedAt,
  }) {
    return SimCardModel(
      id: id ?? this.id,
      operatorCode: operatorCode ?? this.operatorCode,
      operatorName: operatorName ?? this.operatorName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
