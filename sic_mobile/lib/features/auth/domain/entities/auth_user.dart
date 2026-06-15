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
    this.accountType = 'AGENT',
    this.kycTier = 0,
    this.kycRequestedTier,
    this.kycRejectionReason = '',
    this.hasPin = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String kycStatus; // PENDING | APPROVED | REJECTED
  final bool isSuspended;

  /// Type de compte : 'AGENT' (PDV) ou 'CLIENT' (grand public). Pilote la
  /// navigation et les fonctionnalites accessibles (lots D*).
  final String accountType;

  /// Palier KYC (0 = Starter, 1 = verifie, 2 = complet). Pilote les plafonds
  /// (cf moteur de limites backend, endpoint `/auth/limits/`).
  final int kycTier;

  /// Palier demande lors d'une soumission KYC en attente (null si aucune).
  final int? kycRequestedTier;

  /// Motif de rejet de la derniere soumission KYC (vide si aucun).
  final String kycRejectionReason;

  /// Vrai si l'agent a deja configure un code PIN (claim du JWT d'acces).
  final bool hasPin;

  bool get isAgent => accountType.toUpperCase() == 'AGENT';
  bool get isClient => accountType.toUpperCase() == 'CLIENT';

  String get fullName {
    final parts = [firstName, lastName].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? 'Agent SIC' : parts.join(' ');
  }

  bool get isApproved => kycStatus.toUpperCase() == 'APPROVED';
  bool get kycSubmitted => kycStatus.toUpperCase() == 'SUBMITTED';
  bool get kycRejected => kycStatus.toUpperCase() == 'REJECTED';

  AuthUser copyWith({bool? hasPin}) {
    return AuthUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      email: email,
      kycStatus: kycStatus,
      isSuspended: isSuspended,
      accountType: accountType,
      kycTier: kycTier,
      kycRequestedTier: kycRequestedTier,
      kycRejectionReason: kycRejectionReason,
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
        accountType,
        kycTier,
        kycRequestedTier,
        kycRejectionReason,
        hasPin,
      ];
}
