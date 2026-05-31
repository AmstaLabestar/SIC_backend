/// Agent Model for SIC Mobile
class Agent {
  final String id;
  final String? username;
  final String? email;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final String kycStatus; // PENDING, APPROVED, REJECTED
  final bool isSuspended;
  final List<Puce>? puces;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Agent({
    required this.id,
    this.username,
    this.email,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    this.kycStatus = 'PENDING',
    this.isSuspended = false,
    this.puces,
    this.createdAt,
    this.updatedAt,
  });

  /// Get display name
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) {
      return firstName!;
    }
    if (lastName != null) {
      return lastName!;
    }
    return username ?? phoneNumber;
  }

  /// Get initials for avatar
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    return phoneNumber.substring(0, 2);
  }

  /// Check if KYC is approved
  bool get isKycApproved => kycStatus == 'APPROVED';

  /// Check if KYC is pending
  bool get isKycPending => kycStatus == 'PENDING';

  /// Check if KYC is rejected
  bool get isKycRejected => kycStatus == 'REJECTED';

  /// Check if account is active
  bool get isActive => !isSuspended && isKycApproved;

  /// Calculate total balance from puces
  double get totalBalance {
    if (puces == null) return 0.0;
    return puces!.fold(0.0, (sum, puce) => sum + puce.balance);
  }

  /// Create from JSON
  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      email: json['email'],
      phoneNumber: json['phone_number'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      kycStatus: json['kyc_status'] ?? 'PENDING',
      isSuspended: json['is_suspended'] ?? false,
      puces: json['puces'] != null
          ? (json['puces'] as List).map((p) => Puce.fromJson(p)).toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'kyc_status': kycStatus,
      'is_suspended': isSuspended,
      'puces': puces?.map((p) => p.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copy with updated values
  Agent copyWith({
    String? id,
    String? username,
    String? email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? kycStatus,
    bool? isSuspended,
    List<Puce>? puces,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Agent(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      kycStatus: kycStatus ?? this.kycStatus,
      isSuspended: isSuspended ?? this.isSuspended,
      puces: puces ?? this.puces,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Agent(id: $id, name: $displayName, kycStatus: $kycStatus)';
  }
}

/// Puce Model (SIM Card)
class Puce {
  final String id;
  final String operator; // ORANGE, MOOV, TELECEL, CORIS
  final String phoneNumber;
  final double balance;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Puce({
    required this.id,
    required this.operator,
    required this.phoneNumber,
    this.balance = 0.0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Get formatted phone number
  String get formattedPhone {
    if (phoneNumber.length == 8) {
      return '${phoneNumber.substring(0, 2)} ${phoneNumber.substring(2, 4)} ${phoneNumber.substring(4, 6)} ${phoneNumber.substring(6, 8)}';
    }
    return phoneNumber;
  }

  /// Get operator display name
  String get operatorName {
    switch (operator.toUpperCase()) {
      case 'ORANGE':
        return 'Orange';
      case 'MOOV':
        return 'Moov';
      case 'TELECEL':
        return 'Togocel';
      case 'CORIS':
        return 'Coris';
      default:
        return operator;
    }
  }

  /// Create from JSON
  factory Puce.fromJson(Map<String, dynamic> json) {
    return Puce(
      id: json['id']?.toString() ?? '',
      operator: json['operator'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      balance: _parseDouble(json['balance']),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operator': operator,
      'phone_number': phoneNumber,
      'balance': balance,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copy with updated values
  Puce copyWith({
    String? id,
    String? operator,
    String? phoneNumber,
    double? balance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Puce(
      id: id ?? this.id,
      operator: operator ?? this.operator,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Puce(id: $id, operator: $operator, phone: $phoneNumber, balance: $balance)';
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