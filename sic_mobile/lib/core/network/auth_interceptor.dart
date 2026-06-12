import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// Intercepteur JWT :
/// - injecte `Authorization: Bearer <access>` (sauf endpoints d'auth publics) ;
/// - sur 401, tente un refresh unique (single-flight) puis rejoue la requete ;
/// - si le refresh echoue, purge les tokens et notifie [onSessionExpired].
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required this.onSessionExpired,
  })  : _storage = storage,
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
          ),
        );

  final TokenStorage _storage;
  final Dio _refreshDio;
  final void Function() onSessionExpired;

  static const _publicPaths = <String>{
    ApiConstants.login,
    ApiConstants.register,
    ApiConstants.refresh,
    ApiConstants.health,
  };

  /// Endpoints ou un 401 est metier (pas une session expiree) : il ne faut NI
  /// rafraichir le token NI rejouer la requete. Sur `pin/verify`, un 401 signifie
  /// "PIN incorrect" ; un retry doublerait le compteur de tentatives backend.
  static const _businessAuthPaths = <String>{
    ApiConstants.pinVerify,
  };

  bool _isPublic(String path) => _publicPaths.any(path.contains);

  bool _isBusinessAuth(String path) => _businessAuthPaths.any(path.contains);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final access = await _storage.readAccess();
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final isAuthError = response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;

    if (!isAuthError ||
        alreadyRetried ||
        _isPublic(err.requestOptions.path) ||
        _isBusinessAuth(err.requestOptions.path)) {
      return handler.next(err);
    }

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      await _storage.clear();
      onSessionExpired();
      return handler.next(err);
    }

    try {
      final access = await _storage.readAccess();
      final options = err.requestOptions
        ..extra['__retried__'] = true
        ..headers['Authorization'] = 'Bearer $access';
      final clone = await _refreshDio.fetch<dynamic>(options);
      return handler.resolve(clone);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.readRefresh();
    if (refresh == null) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiConstants.refresh,
        data: {'refresh': refresh},
      );
      final access = response.data?['access'] as String?;
      if (access == null) return false;
      await _storage.saveAccess(access);
      // simplejwt peut renvoyer un nouveau refresh (ROTATE_REFRESH_TOKENS).
      final newRefresh = response.data?['refresh'] as String?;
      if (newRefresh != null) {
        await _storage.saveTokens(access: access, refresh: newRefresh);
      }
      return true;
    } on DioException {
      return false;
    }
  }
}
