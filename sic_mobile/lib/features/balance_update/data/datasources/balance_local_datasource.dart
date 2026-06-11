import '../models/balance_update_model.dart';

class BalanceLocalDatasource {
  BalanceLocalDatasource();

  static final Map<String, List<BalanceUpdateModel>> _historyByOperator = {
    'OM': [
      BalanceUpdateModel(
        operatorCode: 'OM',
        previousBalance: 210000,
        newBalance: 250000,
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ],
    'MOOV': [
      BalanceUpdateModel(
        operatorCode: 'MOOV',
        previousBalance: 70000,
        newBalance: 85000,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ],
    'TELECEL': [
      BalanceUpdateModel(
        operatorCode: 'TELECEL',
        previousBalance: 120000,
        newBalance: 150000,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ],
  };

  Future<BalanceUpdateModel> updateBalance({
    required String operatorCode,
    required double previousBalance,
    required double newBalance,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final update = BalanceUpdateModel(
      operatorCode: operatorCode,
      previousBalance: previousBalance,
      newBalance: newBalance,
      updatedAt: DateTime.now(),
    );

    final history = _historyByOperator.putIfAbsent(operatorCode, () => []);
    history.insert(0, update);

    if (history.length > 10) {
      history.removeRange(10, history.length);
    }

    return update;
  }

  Future<List<BalanceUpdateModel>> getBalanceHistory(
    String operatorCode,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    return List<BalanceUpdateModel>.unmodifiable(
      _historyByOperator[operatorCode] ?? [],
    );
  }
}
