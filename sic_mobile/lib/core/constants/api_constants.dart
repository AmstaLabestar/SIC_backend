import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Constantes de l'API SIC (backend Django).
///
/// Le backend expose les routes sous `/api/` (pas `/api/v1`).
/// - Emulateur Android : `http://10.0.2.2:8000/api`
/// - Telephone physique : `http://<IP_LAN_DU_PC>:8000/api` (via .env)
/// - Web : `http://localhost:8000/api`
class ApiConstants {
  const ApiConstants._();

  static String get baseUrl {
    final fromEnv =
        dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    return fromEnv ?? 'http://10.0.2.2:8000/api';
  }

  static const connectTimeout = Duration(milliseconds: 30000);
  static const receiveTimeout = Duration(milliseconds: 30000);

  // Auth
  static const login = '/auth/login/';
  static const register = '/auth/register/';
  static const refresh = '/auth/refresh/';
  static const logout = '/auth/logout/';
  static const profile = '/auth/profile/';

  // Ressources
  static const puces = '/puces/';
  static const transactions = '/transactions/';
  static const commissions = '/commissions/';
  static const health = '/health/';

  static String puce(String id) => '/puces/$id/';
  static String puceTopup(String id) => '/puces/$id/topup/';
}
