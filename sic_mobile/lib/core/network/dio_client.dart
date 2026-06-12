import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Fabrique le client Dio configure (base URL, timeouts, intercepteur JWT).
Dio createDioClient({
  required TokenStorage storage,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(storage: storage, onSessionExpired: onSessionExpired),
  );

  // TODO(security): activer le certificate pinning (SHA-256 du cert backend)
  // via un HttpClientAdapter/badCertificateCallback avant la mise en production.

  return dio;
}
