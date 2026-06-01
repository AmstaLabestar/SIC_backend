import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sic_mobile/config/constants.dart';

/// API Service for SIC Mobile
/// Handles all HTTP requests with JWT authentication
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  // ============================================================================
  // TOKEN MANAGEMENT
  // ============================================================================

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }

  bool get isAuthenticated {
    return _storage.read(key: StorageKeys.accessToken) != null;
  }

  // ============================================================================
  // INTERCEPTORS
  // ============================================================================

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add authorization header if token exists
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (kDebugMode) {
      print('🌐 REQUEST[${options.method}] => PATH: ${options.path}');
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      print('❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
      print('Error: ${err.message}');
    }

    // Handle 401 Unauthorized - try to refresh token
    if (err.response?.statusCode == 401) {
      try {
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry the original request
          final opts = err.requestOptions;
          final token = await getAccessToken();
          opts.headers['Authorization'] = 'Bearer $token';

          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        }
      } catch (e) {
        // Refresh failed, clear tokens
        await clearTokens();
      }
    }

    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConstants.refresh,
        data: {'refresh': refreshToken},
        options: Options(headers: {}), // Skip auth header
      );

      if (response.statusCode == 200) {
        await saveTokens(
          accessToken: response.data['access'],
          refreshToken: response.data['refresh'] ?? refreshToken,
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Token refresh failed: $e');
    }
    return false;
  }

  // ============================================================================
  // HTTP METHODS
  // ============================================================================

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  // ============================================================================
  // AUTH METHODS
  // ============================================================================

  Future<ApiResponse> login(String username, String password) async {
    try {
      final response = await post(
        ApiConstants.login,
        data: {
          'username': username,
          'password': password,
        },
        options: Options(headers: {}), // Skip auth
      );

      await saveTokens(
        accessToken: response.data['access'],
        refreshToken: response.data['refresh'],
      );

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await post(
        ApiConstants.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': password,
          'phone_number': phoneNumber,
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
        },
        options: Options(headers: {}),
      );

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> getProfile() async {
    try {
      final response = await get(ApiConstants.profile);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> setupPin(String password, String pin, String pinConfirm) async {
    try {
      final response = await post(
        ApiConstants.pinSetup,
        data: {
          'password': password,
          'pin': pin,
          'pin_confirm': pinConfirm,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> verifyPin(String pin) async {
    try {
      final response = await post(
        ApiConstants.pinVerify,
        data: {'pin': pin},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> registerBiometric({
    required String deviceId,
    required String publicKeyBase64,
  }) async {
    try {
      final response = await post(
        ApiConstants.biometricRegister,
        data: {
          'device_id': deviceId,
          'public_key': publicKeyBase64,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> biometricLogin({
    required String deviceId,
    required int timestamp,
    required String signatureBase64,
  }) async {
    try {
      final response = await post(
        ApiConstants.biometricLogin,
        data: {
          'device_id': deviceId,
          'timestamp': timestamp,
          'signature': signatureBase64,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        // Save tokens if provided
        if (response.data['access'] != null) {
          await saveTokens(
            accessToken: response.data['access'],
            refreshToken: response.data['refresh'] ?? '',
          );
        }
      }
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        await clearTokens();
        return ApiResponse.success(null);
      }

      await post(
        ApiConstants.logout,
        data: {'refresh': refreshToken},
      );
      await clearTokens();
      return ApiResponse.success(null);
    } catch (e) {
      await clearTokens();
      return ApiResponse.success(null);
    }
  }

  // ============================================================================
  // TRANSACTION METHODS
  // ============================================================================

  Future<ApiResponse> getTransactions({int page = 1}) async {
    try {
      final response = await get(
        ApiConstants.transactions,
        queryParameters: {'page': page},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> getTransaction(String id) async {
    try {
      final response = await get('${ApiConstants.transactions}$id/');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> deposit({
    required double amount,
    required String targetOperator,
    required String targetPhoneNumber,
    String? pinToken,
  }) async {
    try {
      final response = await post(
        ApiConstants.deposit,
        data: {
          'amount': amount,
          'target_operator': targetOperator.toUpperCase(),
          'target_phone_number': targetPhoneNumber,
          if (pinToken != null) 'pin_token': pinToken,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> withdraw({
    required double amount,
    required String targetOperator,
    required String targetPhoneNumber,
    String? pinToken,
  }) async {
    try {
      final response = await post(
        ApiConstants.withdraw,
        data: {
          'amount': amount,
          'target_operator': targetOperator.toUpperCase(),
          'target_phone_number': targetPhoneNumber,
          if (pinToken != null) 'pin_token': pinToken,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
    String? pinToken,
  }) async {
    try {
      final response = await post(
        ApiConstants.conversion,
        data: {
          'amount': amount,
          'source_puce_id': sourcePuceId,
          'target_puce_id': targetPuceId,
          if (pinToken != null) 'pin_token': pinToken,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  // ============================================================================
  // PUCE METHODS
  // ============================================================================

  Future<ApiResponse> getPuces() async {
    try {
      final response = await get(ApiConstants.puces);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> addPuce({
    required String operator,
    required String phoneNumber,
  }) async {
    try {
      final response = await post(
        ApiConstants.puces,
        data: {
          'operator': operator.toUpperCase(),
          'phone_number': phoneNumber,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> deletePuce(String id) async {
    try {
      await delete('${ApiConstants.puces}$id/');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  // ============================================================================
  // INFO METHODS
  // ============================================================================

  Future<ApiResponse> getCommissions() async {
    try {
      final response = await get(ApiConstants.commissions);
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('Une erreur est survenue');
    }
  }

  Future<ApiResponse> healthCheck() async {
    try {
      final response = await get(
        ApiConstants.health,
        options: Options(headers: {}),
      );
      return ApiResponse.success(response.data);
    } catch (e) {
      return ApiResponse.error('Serveur indisponible');
    }
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

  String _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('message')) return data['message'].toString();
        // Handle field errors
        final errors = data.entries
            .where((e) => e.value is List)
            .map((e) => '${e.key}: ${(e.value as List).join(", ")}')
            .join('\n');
        if (errors.isNotEmpty) return errors;
      }
      if (data is String) return data;

      switch (e.response!.statusCode) {
        case 400:
          return 'Requête invalide';
        case 401:
          return 'Non autorisé. Veuillez vous reconnecter';
        case 403:
          return 'Accès refusé';
        case 404:
          return 'Ressource non trouvée';
        case 429:
          return 'Trop de requêtes. Veuillez patienter';
        case 500:
          return 'Erreur serveur. Veuillez réessayer';
        default:
          return 'Erreur ${e.response!.statusCode}';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai de connexion dépassé';
      case DioExceptionType.connectionError:
        return 'Pas de connexion internet';
      case DioExceptionType.cancel:
        return 'Requête annulée';
      default:
        return 'Une erreur est survenue';
    }
  }
}

/// Generic API Response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse._({this.data, this.error, required this.isSuccess});

  factory ApiResponse.success(T? data) {
    return ApiResponse._(data: data, isSuccess: true);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(error: message, isSuccess: false);
  }

  @override
  String toString() {
    return isSuccess ? 'ApiResponse.success($data)' : 'ApiResponse.error($error)';
  }
}