import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/balance_update_model.dart';

/// Reconciliation du solde d'une puce via `POST /puces/{id}/set_balance/`.
class BalanceRemoteDatasource {
  const BalanceRemoteDatasource(this._dio);

  final Dio _dio;

  Future<BalanceUpdateModel> setBalance({
    required String puceId,
    required double newBalance,
    required String? pinToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.puceSetBalance(puceId),
      data: {'balance': newBalance},
      options: pinToken == null
          ? null
          : Options(headers: {'X-PIN-TOKEN': pinToken}),
    );
    return BalanceUpdateModel.fromResponse(puceId, response.data!);
  }
}
