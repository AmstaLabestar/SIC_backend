class ServerException implements Exception {
  const ServerException(this.message, this.statusCode);

  final String message;
  final int statusCode;
}

class NetworkException implements Exception {
  const NetworkException();
}

class CacheException implements Exception {
  const CacheException(this.message);

  final String message;
}

class AuthException implements Exception {
  const AuthException();
}
