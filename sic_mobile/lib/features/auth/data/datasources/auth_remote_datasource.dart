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
}
