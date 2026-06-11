// import 'package:dio/dio.dart';
//
// import '../../../../core/constants/api_constants.dart';
// import '../models/sim_card_model.dart';
//
// TODO: Uncomment and wire this datasource when the Django backend is ready.
// class SimRemoteDatasource {
//   const SimRemoteDatasource(this.dio);
//
//   final Dio dio;
//
//   Future<List<SimCardModel>> getSims() async {
//     final response = await dio.get<Map<String, dynamic>>(ApiConstants.sims);
//     final results = response.data!['results'] as List<dynamic>;
//     return results
//         .map((json) => SimCardModel.fromJson(json as Map<String, dynamic>))
//         .toList();
//   }
// }
