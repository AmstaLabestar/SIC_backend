import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/operator_mapping.dart';
import '../models/agent_transaction_model.dart';
import '../models/operation_result_model.dart';

/// Appels reseau des operations (peut lever [DioException]).
class TransactionRemoteDatasource {
  const TransactionRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<AgentTransactionModel>> getTransactions() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.transactions,
    );
    final results = (response.data?['results'] as List<dynamic>?) ?? const [];
    return results
        .map((e) => AgentTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OperationResultModel> deposit({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) {
    return _operation(
      ApiConstants.deposit,
      amount,
      operatorCode,
      phoneNumber,
      pinToken,
    );
  }

  Future<OperationResultModel> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) {
    return _operation(
      ApiConstants.withdraw,
      amount,
      operatorCode,
      phoneNumber,
      pinToken,
    );
  }

  Future<OperationResultModel> transfer({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
    String? pinToken,
  }) {
    return _operation(
      ApiConstants.transfer,
      amount,
      operatorCode,
      phoneNumber,
      pinToken,
    );
  }

  Future<OperationResultModel> _operation(
    String path,
    double amount,
    String operatorCode,
    String phoneNumber,
    String? pinToken,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {
        'amount': amount,
        'target_operator': OperatorMapping.toBackend(operatorCode),
        'target_phone_number': phoneNumber,
      },
      options: _pinOptions(pinToken),
    );
    return OperationResultModel.fromJson(response.data!);
  }

  Future<OperationResultModel> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
    String? pinToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.conversion,
      data: {
        'amount': amount,
        'source_puce_id': sourcePuceId,
        'target_puce_id': targetPuceId,
      },
      options: _pinOptions(pinToken),
    );
    return OperationResultModel.fromJson(response.data!);
  }

  /// Transmet le `pin_token` au backend via l'en-tete `X-PIN-TOKEN` (exige
  /// pour toute operation des qu'un PIN est configure). Aucun en-tete si null.
  Options? _pinOptions(String? pinToken) {
    if (pinToken == null) return null;
    return Options(headers: {'X-PIN-TOKEN': pinToken});
  }
}
