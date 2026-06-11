import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/balance_summary.dart';

BalanceSummary _make({
  String operatorCode = 'OM',
  String phoneNumber = '0701234234',
  double balance = 250000,
  bool isLow = false,
  double alertThreshold = 50000,
  bool isActive = true,
}) {
  return BalanceSummary(
    operatorCode: operatorCode,
    operatorName: 'Orange Money',
    phoneNumber: phoneNumber,
    balance: balance,
    isLow: isLow,
    alertThreshold: alertThreshold,
    lastUpdated: DateTime(2024, 1, 15),
    isActive: isActive,
  );
}

void main() {
  group('BalanceSummary', () {
    test('maskedPhone masque le milieu (07•••234)', () {
      expect(_make(phoneNumber: '0701234234').maskedPhone, '07•••234');
    });

    test('maskedPhone masque le milieu (06•••891)', () {
      expect(_make(phoneNumber: '0601238891').maskedPhone, '06•••891');
    });

    test('isEmpty est true quand balance <= 0', () {
      expect(_make(balance: 0).isEmpty, isTrue);
    });

    test('isEmpty est false quand balance > 0', () {
      expect(_make(balance: 1000).isEmpty, isFalse);
    });

    test('copyWith recalcule isLow depuis le seuil', () {
      final updated = _make(balance: 50000, isLow: false).copyWith(
        balance: 20000,
      );
      expect(updated.balance, 20000);
      expect(updated.isLow, isTrue);
    });

    test('isActive fait partie de l\'egalite Equatable', () {
      expect(_make(isActive: true) == _make(isActive: false), isFalse);
    });
  });
}
