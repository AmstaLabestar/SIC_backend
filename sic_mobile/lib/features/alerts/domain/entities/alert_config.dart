import 'package:equatable/equatable.dart';

/// Seuil d'alerte de solde, rattache a une puce (float). Granularite per-puce :
/// chaque puce a sa propre alerte (cf. backend `AlertConfig`).
class AlertConfig extends Equatable {
  const AlertConfig({
    required this.id,
    required this.puceId,
    required this.operatorCode,
    required this.operatorName,
    required this.phoneNumber,
    required this.isEnabled,
    required this.threshold,
    required this.lastUpdated,
  });

  /// Identifiant de la config d'alerte (sert au PATCH `/alerts/{id}/`).
  final String id;
  final String puceId;
  final String operatorCode;
  final String operatorName;
  final String phoneNumber;
  final bool isEnabled;
  final double threshold;
  final DateTime lastUpdated;

  AlertConfig copyWith({
    String? id,
    String? puceId,
    String? operatorCode,
    String? operatorName,
    String? phoneNumber,
    bool? isEnabled,
    double? threshold,
    DateTime? lastUpdated,
  }) {
    return AlertConfig(
      id: id ?? this.id,
      puceId: puceId ?? this.puceId,
      operatorCode: operatorCode ?? this.operatorCode,
      operatorName: operatorName ?? this.operatorName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEnabled: isEnabled ?? this.isEnabled,
      threshold: threshold ?? this.threshold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        id,
        puceId,
        operatorCode,
        operatorName,
        phoneNumber,
        isEnabled,
        threshold,
        lastUpdated,
      ];
}
