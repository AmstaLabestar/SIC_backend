/// Commission Info Model for SIC Mobile
class CommissionInfo {
  final Map<String, CommissionRate> commissions;
  final int minAmount;
  final int maxAmount;

  CommissionInfo({
    required this.commissions,
    required this.minAmount,
    required this.maxAmount,
  });

  /// Get commission rate for a transaction type
  CommissionRate? getRate(String type) {
    return commissions[type.toUpperCase()];
  }

  /// Create from JSON
  factory CommissionInfo.fromJson(Map<String, dynamic> json) {
    final Map<String, CommissionRate> commissionsMap = {};

    if (json['commissions'] != null) {
      final commissionsData = json['commissions'] as Map<String, dynamic>;
      commissionsData.forEach((key, value) {
        commissionsMap[key] = CommissionRate.fromJson(value);
      });
    }

    return CommissionInfo(
      commissions: commissionsMap,
      minAmount: json['min_amount'] ?? 100,
      maxAmount: json['max_amount'] ?? 5000000,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'commissions': commissions.map((key, value) => MapEntry(key, value.toJson())),
      'min_amount': minAmount,
      'max_amount': maxAmount,
    };
  }
}

/// Commission Rate for a transaction type
class CommissionRate {
  final double sicRate; // Percentage
  final double agentRate; // Percentage

  CommissionRate({
    required this.sicRate,
    required this.agentRate,
  });

  /// Calculate SIC commission for an amount
  double calculateSicCommission(double amount) {
    return amount * (sicRate / 100);
  }

  /// Calculate agent benefit for an amount
  double calculateAgentBenefit(double amount) {
    return amount * (agentRate / 100);
  }

  /// Calculate total commission
  double get totalRate => sicRate + agentRate;

  /// Create from JSON
  factory CommissionRate.fromJson(Map<String, dynamic> json) {
    return CommissionRate(
      sicRate: _parseDouble(json['sic_rate']),
      agentRate: _parseDouble(json['agent_rate']),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sic_rate': sicRate,
      'agent_rate': agentRate,
    };
  }
}

/// Helper to parse double from dynamic
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}