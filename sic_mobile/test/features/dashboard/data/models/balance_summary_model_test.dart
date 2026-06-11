import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/data/models/balance_summary_model.dart';

void main() {
  group('BalanceSummaryModel', () {
    test('fromJson parse un JSON valide', () {
      final model = BalanceSummaryModel.fromJson({
        'operator_code': 'OM',
        'operator_name': 'Orange Money',
        'phone_number': '0701234234',
        'balance': 250000,
        'is_low': false,
        'alert_threshold': 50000,
        'last_updated': '2024-01-15T10:30:00Z',
        'is_active': true,
      });

      expect(model.operatorCode, 'OM');
      expect(model.balance, 250000);
      expect(model.isLow, isFalse);
      expect(model.isActive, isTrue);
    });

    test('fromJson : is_active vaut true par defaut si absent', () {
      final model = BalanceSummaryModel.fromJson({
        'operator_code': 'OM',
        'operator_name': 'Orange Money',
        'phone_number': '0701234234',
        'balance': 0,
        'is_low': true,
        'alert_threshold': 50000,
        'last_updated': '2024-01-15T10:30:00Z',
      });

      expect(model.isActive, isTrue);
    });

    test('toJson serialise les champs cles', () {
      final model = BalanceSummaryModel(
        operatorCode: 'OM',
        operatorName: 'Orange Money',
        phoneNumber: '0701234234',
        balance: 250000,
        isLow: false,
        alertThreshold: 50000,
        lastUpdated: DateTime.utc(2024, 1, 15, 10, 30),
        isActive: true,
      );

      final json = model.toJson();
      expect(json['operator_code'], 'OM');
      expect(json['balance'], 250000);
      expect(json['is_active'], true);
      expect(json['last_updated'], '2024-01-15T10:30:00.000Z');
    });
  });
}
