import '../../domain/entities/alert_config.dart';

class AlertConfigModel extends AlertConfig {
  const AlertConfigModel({
    required super.operatorCode,
    required super.operatorName,
    required super.isEnabled,
    required super.threshold,
    required super.lastUpdated,
  });

  factory AlertConfigModel.fromEntity(AlertConfig config) {
    return AlertConfigModel(
      operatorCode: config.operatorCode,
      operatorName: config.operatorName,
      isEnabled: config.isEnabled,
      threshold: config.threshold,
      lastUpdated: config.lastUpdated,
    );
  }

  factory AlertConfigModel.fromJson(Map<dynamic, dynamic> json) {
    return AlertConfigModel(
      operatorCode: json['operator_code'] as String,
      operatorName: json['operator_name'] as String,
      isEnabled: json['is_enabled'] as bool,
      threshold: (json['threshold'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['last_updated'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operator_code': operatorCode,
      'operator_name': operatorName,
      'is_enabled': isEnabled,
      'threshold': threshold,
      'last_updated': lastUpdated.toUtc().toIso8601String(),
    };
  }
}
