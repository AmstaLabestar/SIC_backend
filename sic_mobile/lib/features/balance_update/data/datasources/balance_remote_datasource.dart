// import 'package:dio/dio.dart';
//
// import '../models/balance_update_model.dart';
//
// TODO: Uncomment and wire this datasource when the Django backend is ready.
// class BalanceRemoteDatasource {
//   const BalanceRemoteDatasource(this.dio);
//
//   final Dio dio;
//
//   Future<BalanceUpdateModel> updateBalance({
//     required String simId,
//     required double newBalance,
//     required DateTime updatedAt,
//   }) async {
//     final response = await dio.patch<Map<String, dynamic>>(
//       '/sims/$simId/balance/',
//       data: {
//         'balance': newBalance,
//         'updated_at': updatedAt.toUtc().toIso8601String(),
//       },
//     );
//
//     return BalanceUpdateModel.fromJson(response.data!);
//   }
// }
