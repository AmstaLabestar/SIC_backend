import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/alert_config_model.dart';

/// Acces backend aux seuils d'alerte de solde (`/alerts/`).
class AlertRemoteDatasource {
  const AlertRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<AlertConfigModel>> getAlertConfigs() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiConstants.alerts);
    final results = (response.data!['results'] as List<dynamic>?) ?? const [];
    return results
        .map((json) => AlertConfigModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<AlertConfigModel> updateAlertConfig({
    required String id,
    required double threshold,
    required bool isEnabled,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiConstants.alert(id),
      data: AlertConfigModel.updatePayload(
        threshold: threshold,
        isEnabled: isEnabled,
      ),
    );
    return AlertConfigModel.fromJson(response.data!);
  }
}
