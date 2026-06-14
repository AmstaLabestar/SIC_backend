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

  /// Connexion par numero de telephone (identifiant principal v1, lot A3).
  /// Le backend resout le numero vers le compte ; un username reste accepte en
  /// repli (comptes existants / demo), d'ou le nom generique [identifier].
  Future<AuthTokens> login(String identifier, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'phone_number': identifier, 'password': password},
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

  /// Envoie un code OTP de verification a l'email (`POST /auth/otp/send/`).
  Future<void> sendOtp(String email) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.otpSend,
      data: {'email': email, 'purpose': 'register'},
    );
  }

  /// Inscription d'un nouvel agent (`POST /auth/register/`).
  /// Exige le code [otp] recu par email. Le backend cree un compte KYC=PENDING
  /// et ne renvoie pas de tokens.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String otp,
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
        'otp': otp,
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
