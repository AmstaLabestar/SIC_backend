import 'package:equatable/equatable.dart';

/// Agent authentifie (profil minimal).
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.kycStatus,
    required this.isSuspended,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String kycStatus; // PENDING | APPROVED | REJECTED
  final bool isSuspended;

  String get fullName {
    final parts = [firstName, lastName].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? 'Agent SIC' : parts.join(' ');
  }

  bool get isApproved => kycStatus.toUpperCase() == 'APPROVED';

  @override
  List<Object?> get props =>
      [id, firstName, lastName, phoneNumber, email, kycStatus, isSuspended];
}
