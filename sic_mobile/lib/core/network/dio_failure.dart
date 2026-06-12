import 'package:dio/dio.dart';

import '../errors/failures.dart';

/// Convertit une erreur Dio en [Failure] typee pour la couche presentation.
Failure mapDioErrorToFailure(Object error) {
  if (error is! DioException) {
    return const ServerFailure('Erreur inattendue.');
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
      return const ServerFailure('Certificat invalide.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final response = error.response;
  final statusCode = response?.statusCode;
  final message = _extractMessage(response?.data) ?? 'Erreur serveur.';

  if (statusCode == null) {
    return const NetworkFailure();
  }
  if (statusCode == 401) return const AuthFailure();
  if (statusCode == 403) return const ServerFailure('Acces refuse.', 403);
  if (statusCode == 404) return const NotFoundFailure();
  if (statusCode >= 400 && statusCode < 500) {
    return ValidationFailure(message);
  }
  return ServerFailure(message, statusCode);
}

/// Le backend renvoie `{ "error": "...", "message": "..." }` ou des erreurs DRF.
String? _extractMessage(Object? data) {
  if (data is Map) {
    final message = data['message'] ?? data['detail'] ?? data['error'];
    if (message is String && message.isNotEmpty) return message;
    // Erreurs de validation DRF : { "field": ["msg"] }
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
  }
  if (data is String && data.isNotEmpty) return data;
  return null;
}
