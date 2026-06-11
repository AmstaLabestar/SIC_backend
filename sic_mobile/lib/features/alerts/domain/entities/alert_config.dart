import 'package:equatable/equatable.dart';

class AlertConfig extends Equatable {
  const AlertConfig({
    required this.operatorCode,
    required this.operatorName,
    required this.isEnabled,
    required this.threshold,
    required this.lastUpdated,
  });

  final String operatorCode;
  final String operatorName;
  final bool isEnabled;
  final double threshold;
  final DateTime lastUpdated;

  AlertConfig copyWith({
    String? operatorCode,
    String? operatorName,
    bool? isEnabled,
    double? threshold,
    DateTime? lastUpdated,
  }) {
    return AlertConfig(
      operatorCode: operatorCode ?? this.operatorCode,
      operatorName: operatorName ?? this.operatorName,
      isEnabled: isEnabled ?? this.isEnabled,
      threshold: threshold ?? this.threshold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        operatorCode,
        operatorName,
        isEnabled,
        threshold,
        lastUpdated,
      ];
}
