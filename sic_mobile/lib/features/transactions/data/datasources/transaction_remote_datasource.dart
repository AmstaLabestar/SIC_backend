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
  }) {
    return _operation(ApiConstants.deposit, amount, operatorCode, phoneNumber);
  }

  Future<OperationResultModel> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
  }) {
    return _operation(ApiConstants.withdraw, amount, operatorCode, phoneNumber);
  }

  Future<OperationResultModel> _operation(
    String path,
    double amount,
    String operatorCode,
    String phoneNumber,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {
        'amount': amount,
        'target_operator': OperatorMapping.toBackend(operatorCode),
        'target_phone_number': phoneNumber,
      },
    );
    return OperationResultModel.fromJson(response.data!);
  }

  Future<OperationResultModel> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.conversion,
      data: {
        'amount': amount,
        'source_puce_id': sourcePuceId,
        'target_puce_id': targetPuceId,
      },
    );
    return OperationResultModel.fromJson(response.data!);
  }
}
