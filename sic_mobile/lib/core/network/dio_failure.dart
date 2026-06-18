import 'package:dio/dio.dart';

import '../errors/failures.dart';

/// Convertit une erreur Dio en [Failure] typee pour la couche presentation.
///
/// Securite : on n'expose JAMAIS le corps brut d'une reponse a l'utilisateur.
/// Un serveur en erreur peut renvoyer une page HTML (trace, chemins, versions) ;
/// l'afficher fuiterait des details techniques. On ne reprend donc un message
/// que s'il provient d'une reponse JSON structuree (Map), et pour les 5xx on
/// affiche un message generique.
Failure mapDioErrorToFailure(Object error) {
  if (error is! DioException) {
    return const ServerFailure('Une erreur inattendue est survenue.');
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const ServerFailure('Requete annulee.');
    case DioExceptionType.badCertificate:
      return const ServerFailure('Connexion non securisee.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final response = error.response;
  final statusCode = response?.statusCode;

  if (statusCode == null) {
    return const NetworkFailure();
  }
  if (statusCode == 401) return const AuthFailure();
  if (statusCode == 403) return const ServerFailure('Acces refuse.', 403);
  if (statusCode == 404) return const NotFoundFailure();

  // 4xx : on ne reprend que le message d'une reponse JSON de l'API (validation),
  // jamais un corps brut/HTML.
  if (statusCode >= 400 && statusCode < 500) {
    return ValidationFailure(
      _jsonMessage(response?.data) ?? 'Requete invalide.',
    );
  }

  // 5xx : message generique, aucun detail serveur expose.
  return ServerFailure(
    'Service momentanement indisponible. Reessayez dans un instant.',
    statusCode,
  );
}

/// Extrait un message UNIQUEMENT d'une reponse JSON structuree.
/// Le backend renvoie `{ "error": ... }`, `{ "detail": ... }`, `{ "message": ... }`
/// ou des erreurs de validation DRF `{ "champ": ["msg"] }`. Les corps de type
/// String (souvent du HTML) sont volontairement ignores.
String? _jsonMessage(Object? data) {
  if (data is! Map) return null;
  final direct = data['message'] ?? data['detail'] ?? data['error'];
  if (direct is String && direct.isNotEmpty) return direct;
  for (final value in data.values) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}
