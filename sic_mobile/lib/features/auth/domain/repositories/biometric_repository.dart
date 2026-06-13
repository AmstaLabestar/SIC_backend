import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';

/// Authentification biometrique (palier P1 login + P2 deverrouillage).
abstract class BiometricRepository {
  /// Materiel biometrique present ET au moins une empreinte/visage enrole.
  Future<bool> isAvailable();

  /// La connexion biometrique est activee sur cet appareil (cles presentes).
  Future<bool> isEnabled();

  /// Active la biometrie : genere les cles, enregistre la cle publique cote
  /// backend (requiert une session active). Retourne un message d'erreur via
  /// [Failure], ou `unit` si succes.
  Future<Either<Failure, Unit>> enable();

  /// Connexion par empreinte : signe un defi et echange contre des jetons JWT
  /// (persistes). [Failure] si annule / signature invalide / reseau.
  Future<Either<Failure, Unit>> loginWithBiometric();

  /// Invite biometrique simple pour deverrouiller l'app (session vivante, P2).
  Future<bool> unlock();

  /// Desactive la biometrie sur cet appareil (supprime les cles locales).
  Future<void> disable();
}
