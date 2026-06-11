// import 'package:dio/dio.dart';
//
// import '../../../../core/constants/api_constants.dart';
// import '../models/agent_summary_model.dart';
//
// TODO: Uncomment and wire this datasource when the Django backend is ready.
// class DashboardRemoteDatasource {
//   const DashboardRemoteDatasource(this.dio);
//
//   final Dio dio;
//
//   Future<AgentSummaryModel> getDashboardSummary() async {
//     final response = await dio.get<Map<String, dynamic>>(
//       ApiConstants.dashboardSummary,
//     );
//
//     return AgentSummaryModel.fromJson(response.data!);
//   }
//
//   Future<void> refreshBalance(String operatorCode) async {
//     await dio.patch<void>(
//       '${ApiConstants.sims}$operatorCode/balance/',
//     );
//   }
// }
