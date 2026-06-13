import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import 'auth_remote_datasource.dart' show AuthTokens;

/// Appels reseau de l'authentification biometrique (peut lever [DioException]).
///
/// Schema a cle publique : l'appareil enregistre sa cle publique (authentifie),
/// puis prouve son identite en signant `deviceId:timestamp` (public).
class BiometricRemoteDatasource {
  const BiometricRemoteDatasource(this._dio);

  final Dio _dio;

  /// Enregistre la cle publique de l'appareil (`POST /auth/biometric/register/`).
  /// Requiert une session active (l'agent doit etre connecte).
  Future<void> register({
    required String deviceId,
    required String deviceName,
    required String publicKey,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.biometricRegister,
      data: {
        'device_id': deviceId,
        'device_name': deviceName,
        'public_key': publicKey,
      },
    );
  }

  /// Authentifie par signature biometrique (`POST /auth/biometric/login/`).
  /// [timestamp] est en **secondes** (le backend reconstruit `deviceId:ts` et
  /// verifie la signature dessus ; envoyer des millisecondes invaliderait tout).
  Future<AuthTokens> login({
    required String deviceId,
    required String signature,
    required int timestamp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.biometricLogin,
      data: {
        'device_id': deviceId,
        'signature': signature,
        'timestamp': timestamp,
      },
    );
    final data = response.data!;
    return AuthTokens(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
  }
}
