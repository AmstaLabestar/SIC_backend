import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Authentifie, persiste les tokens et retourne le profil.
  Future<Either<Failure, AuthUser>> login(String username, String password);

  /// Inscrit un nouvel agent (compte cree en attente de validation KYC).
  Future<Either<Failure, Unit>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
  });

  /// Recupere le profil de l'agent connecte.
  Future<Either<Failure, AuthUser>> getProfile();

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
