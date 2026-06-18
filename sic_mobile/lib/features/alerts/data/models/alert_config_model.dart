import '../../../../core/network/operator_mapping.dart';
import '../../domain/entities/alert_config.dart';

class AlertConfigModel extends AlertConfig {
  const AlertConfigModel({
    required super.id,
    required super.puceId,
    required super.operatorCode,
    required super.operatorName,
    required super.phoneNumber,
    required super.isEnabled,
    required super.threshold,
    required super.lastUpdated,
  });

  /// Mappe la reponse backend `/alerts/`. L'operateur backend
  /// (`ORANGE`/`MOOV`/...) est traduit vers le code mobile (`OM`/...).
  factory AlertConfigModel.fromJson(Map<String, dynamic> json) {
    final operator = OperatorMapping.fromBackend(
      (json['operator'] as String?) ?? '',
    );

    return AlertConfigModel(
      id: json['id'].toString(),
      puceId: json['puce_id'].toString(),
      operatorCode: operator.code,
      operatorName: operator.name,
      phoneNumber: (json['phone_number'] as String?) ?? '',
      isEnabled: (json['is_enabled'] as bool?) ?? true,
      threshold: (json['threshold'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  /// Corps du PATCH `/alerts/{id}/` : seuls les champs modifiables.
  static Map<String, dynamic> updatePayload({
    required double threshold,
    required bool isEnabled,
  }) {
    return {
      'threshold': threshold,
      'is_enabled': isEnabled,
    };
  }
}
