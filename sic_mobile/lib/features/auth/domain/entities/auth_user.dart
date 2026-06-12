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
    this.hasPin = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String kycStatus; // PENDING | APPROVED | REJECTED
  final bool isSuspended;

  /// Vrai si l'agent a deja configure un code PIN (claim du JWT d'acces).
  final bool hasPin;

  String get fullName {
    final parts = [firstName, lastName].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? 'Agent SIC' : parts.join(' ');
  }

  bool get isApproved => kycStatus.toUpperCase() == 'APPROVED';

  AuthUser copyWith({bool? hasPin}) {
    return AuthUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      email: email,
      kycStatus: kycStatus,
      isSuspended: isSuspended,
      hasPin: hasPin ?? this.hasPin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phoneNumber,
        email,
        kycStatus,
        isSuspended,
        hasPin,
      ];
}
