import 'package:equatable/equatable.dart';

class BalanceSummary extends Equatable {
  const BalanceSummary({
    required this.operatorCode,
    required this.operatorName,
    required this.phoneNumber,
    required this.balance,
    required this.isLow,
    required this.alertThreshold,
    required this.lastUpdated,
    this.isActive = true,
    this.id,
  });

  /// Identifiant de la puce cote backend (`/puces/{id}/`).
  /// `null` pour les donnees factices/locales sans correspondance serveur.
  final String? id;

  final String operatorCode;
  final String operatorName;
  final String phoneNumber;
  final double balance;
  final bool isLow;
  final double alertThreshold;
  final DateTime lastUpdated;

  /// Mobile Money actif/disponible sur cette SIM.
  final bool isActive;

  bool get isEmpty => balance <= 0;

  /// Numero masque : 2 premiers chiffres + 3 derniers (ex: '07•••234').
  String get maskedPhone {
    if (phoneNumber.length < 5) {
      return phoneNumber;
    }

    return '${phoneNumber.substring(0, 2)}•••'
        '${phoneNumber.substring(phoneNumber.length - 3)}';
  }

  BalanceSummary copyWith({
    String? id,
    String? operatorCode,
    String? operatorName,
    String? phoneNumber,
    double? balance,
    bool? isLow,
    double? alertThreshold,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    final nextBalance = balance ?? this.balance;
    final nextThreshold = alertThreshold ?? this.alertThreshold;

    return BalanceSummary(
      id: id ?? this.id,
      operatorCode: operatorCode ?? this.operatorCode,
      operatorName: operatorName ?? this.operatorName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: nextBalance,
      isLow: isLow ?? nextBalance < nextThreshold,
      alertThreshold: nextThreshold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        operatorCode,
        operatorName,
        phoneNumber,
        balance,
        isLow,
        alertThreshold,
        lastUpdated,
        isActive,
      ];
}
