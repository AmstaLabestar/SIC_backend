import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/auth_user_model.dart';

class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// Appels reseau d'authentification (peut lever [DioException]).
class AuthRemoteDatasource {
  const AuthRemoteDatasource(this._dio);

  final Dio _dio;

  Future<AuthTokens> login(String username, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'username': username, 'password': password},
    );
    final data = response.data!;
    return AuthTokens(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
  }

  Future<AuthUserModel> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.profile,
    );
    return AuthUserModel.fromJson(response.data!);
  }

  Future<void> logout(String refresh) async {
    await _dio.post<void>(ApiConstants.logout, data: {'refresh': refresh});
  }

  /// Inscription d'un nouvel agent (`POST /auth/register/`).
  /// Le backend cree un compte KYC=PENDING et ne renvoie pas de tokens.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'username': username,
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'phone_number': phoneNumber,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
  }

  /// Definit le code PIN (`POST /auth/pin/setup/`).
  /// Le mot de passe du compte est exige par le backend (403 si incorrect).
  Future<void> setupPin({
    required String password,
    required String pin,
    required String pinConfirm,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.pinSetup,
      data: {
        'password': password,
        'pin': pin,
        'pin_confirm': pinConfirm,
      },
    );
  }

  /// Verifie le code PIN (`POST /auth/pin/verify/`) et retourne un jeton
  /// temporaire (`pin_token`, valable ~5 min) a transmettre aux operations.
  /// Leve une [DioException] : 401 PIN incorrect, 429 compte verrouille.
  Future<String> verifyPin(String pin) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.pinVerify,
      data: {'pin': pin},
    );
    return response.data!['pin_token'] as String;
  }
}
