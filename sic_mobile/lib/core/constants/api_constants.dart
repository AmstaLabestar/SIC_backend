import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  const ApiConstants._();

  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
  }

  static const connectTimeout = Duration(milliseconds: 30000);
  static const receiveTimeout = Duration(milliseconds: 30000);

  static const dashboardSummary = '/dashboard/summary/';
  static const sims = '/sims/';
  static const alerts = '/alerts/';
}
