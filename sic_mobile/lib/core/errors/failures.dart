import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, [this.statusCode]);

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('Connexion indisponible.');
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure() : super('Session expiree. Reconnectez-vous.');
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Nouvel appareil detecte au login (lot A4 - device binding). Le backend a
/// envoye un OTP par email ; l'app doit demander ce code via /auth/device/verify/.
/// [email] est l'email masque a afficher a l'utilisateur.
class DeviceVerificationFailure extends Failure {
  const DeviceVerificationFailure(this.email)
      : super('Nouvel appareil. Verifiez le code envoye par email.');

  final String email;

  @override
  List<Object?> get props => [message, email];
}

class NotFoundFailure extends Failure {
  const NotFoundFailure() : super('Ressource introuvable.');
}
