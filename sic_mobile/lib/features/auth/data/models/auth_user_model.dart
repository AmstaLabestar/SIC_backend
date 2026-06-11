import '../../domain/entities/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.phoneNumber,
    required super.email,
    required super.kycStatus,
    required super.isSuspended,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      email: json['email'] as String? ?? '',
      kycStatus: json['kyc_status'] as String? ?? 'PENDING',
      isSuspended: json['is_suspended'] as bool? ?? false,
    );
  }
}
