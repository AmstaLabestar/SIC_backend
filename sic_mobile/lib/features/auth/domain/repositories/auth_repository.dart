import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Authentifie, persiste les tokens et retourne le profil.
  /// En cas de nouvel appareil (lot A4), retourne `Left(DeviceVerificationFailure)`
  /// (un OTP a ete envoye par email ; appeler [verifyDevice] ensuite).
  Future<Either<Failure, AuthUser>> login(String username, String password);

  /// Verifie un nouvel appareil par OTP email puis se connecte (lot A4).
  Future<Either<Failure, AuthUser>> verifyDevice({
    required String identifier,
    required String password,
    required String otp,
  });

  /// Envoie un code OTP de verification a l'email (etape 1 de l'inscription).
  Future<Either<Failure, Unit>> sendOtp(String email);

  /// Demande un code de reinitialisation du mot de passe (lot A5).
  /// [identifier] = numero de telephone, email ou username.
  Future<Either<Failure, Unit>> requestPasswordReset(String identifier);

  /// Confirme la reinitialisation : verifie l'OTP et applique le nouveau mot
  /// de passe (lot A5).
  Future<Either<Failure, Unit>> confirmPasswordReset({
    required String identifier,
    required String otp,
    required String newPassword,
  });

  /// Inscrit un nouvel agent (compte cree en attente de validation KYC).
  /// [otp] : code recu par email (verifie cote backend avant creation).
  Future<Either<Failure, Unit>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String otp,
    required String accountType,
    String merchantCode = '',
  });

  /// Recupere le profil de l'agent connecte.
  Future<Either<Failure, AuthUser>> getProfile();

  /// Soumet un dossier KYC (documents + palier demande) pour monter de palier
  /// (lot C3). Retourne le profil mis a jour.
  Future<Either<Failure, AuthUser>> submitKyc({
    required int requestedTier,
    String? idCardFrontPath,
    String? idCardBackPath,
    String? selfiePath,
  });

  /// Definit le code PIN (exige le mot de passe du compte).
  Future<Either<Failure, Unit>> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  });

  /// Verifie le code PIN. Retourne le `pin_token` temporaire en cas de succes.
  Future<Either<Failure, String>> verifyPin(String pin);

  /// Revoque la session (et purge toujours les tokens locaux).
  Future<Either<Failure, Unit>> logout();

  /// Vrai si un refresh token est present localement.
  Future<bool> hasSession();
}
