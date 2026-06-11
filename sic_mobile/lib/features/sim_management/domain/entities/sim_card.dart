import 'package:equatable/equatable.dart';

class SimCard extends Equatable {
  const SimCard({
    required this.id,
    required this.operatorCode,
    required this.operatorName,
    required this.phoneNumber,
    required this.balance,
    required this.isActive,
    required this.alertThreshold,
    required this.addedAt,
  });

  final String id;
  final String operatorCode;
  final String operatorName;
  final String phoneNumber;
  final double balance;
  final bool isActive;
  final double alertThreshold;
  final DateTime addedAt;

  bool get isEmpty => balance <= 0;

  bool get isLow => balance > 0 && balance < alertThreshold;

  SimCard copyWith({
    String? id,
    String? operatorCode,
    String? operatorName,
    String? phoneNumber,
    double? balance,
    bool? isActive,
    double? alertThreshold,
    DateTime? addedAt,
  }) {
    return SimCard(
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

  @override
  List<Object?> get props => [
        id,
        operatorCode,
        operatorName,
        phoneNumber,
        balance,
        isActive,
        alertThreshold,
        addedAt,
      ];
}
