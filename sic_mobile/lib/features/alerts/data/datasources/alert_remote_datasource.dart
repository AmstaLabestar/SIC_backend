// import 'package:dio/dio.dart';
//
// import '../../../../core/constants/api_constants.dart';
// import '../models/alert_config_model.dart';
//
// TODO: Uncomment and wire this datasource when the Django backend is ready.
// class AlertRemoteDatasource {
//   const AlertRemoteDatasource(this.dio);
//
//   final Dio dio;
//
//   Future<List<AlertConfigModel>> getAlertConfigs() async {
//     final response = await dio.get<Map<String, dynamic>>(ApiConstants.alerts);
//     final results = response.data!['results'] as List<dynamic>;
//     return results
//         .map((json) => AlertConfigModel.fromJson(json as Map<String, dynamic>))
//         .toList();
//   }
// }
