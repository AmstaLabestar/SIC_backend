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
  static const deviceVerify = '/auth/device/verify/';
  static const register = '/auth/register/';
  static const otpSend = '/auth/otp/send/';
  static const refresh = '/auth/refresh/';
  static const logout = '/auth/logout/';
  static const passwordResetRequest = '/auth/password/reset/request/';
  static const passwordResetConfirm = '/auth/password/reset/confirm/';
  static const profile = '/auth/profile/';
  static const limits = '/auth/limits/';
  static const kycSubmit = '/auth/kyc/submit/';
  static const pinSetup = '/auth/pin/setup/';
  static const pinVerify = '/auth/pin/verify/';

  // Biometrie (authentification par empreinte, schema cle publique + signature)
  static const biometricRegister = '/auth/biometric/register/';
  static const biometricLogin = '/auth/biometric/login/';
  static const biometricDevices = '/auth/biometric/devices/';

  // Ressources
  static const puces = '/puces/';
  static const transactions = '/transactions/';
  static const alerts = '/alerts/';
  static const commissions = '/commissions/';
  static const health = '/health/';

  // Operations (Phase 3+)
  static const deposit = '/transactions/deposit/';
  static const withdraw = '/transactions/withdraw/';
  static const transfer = '/transactions/transfer/';
  static const conversion = '/transactions/conversion/';
  static const webhook = '/transactions/webhook/';

  static String puce(String id) => '/puces/$id/';
  static String puceTopup(String id) => '/puces/$id/topup/';
  static String puceSetBalance(String id) => '/puces/$id/set_balance/';
  static String transaction(String id) => '/transactions/$id/';
  static String alert(String id) => '/alerts/$id/';
}
