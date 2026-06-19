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
      // Le backend (DRF DecimalField) serialise les montants en String
      // ("50000.00") : on parse de maniere robuste (num OU String).
      threshold: _toDouble(json['threshold']),
      lastUpdated: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  /// Parse un montant qu'il arrive en num (10000) ou en String ("10000.00").
  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
