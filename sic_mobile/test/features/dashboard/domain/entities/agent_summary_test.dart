import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/balance_summary.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/benefit_period.dart';

BalanceSummary _balance({required double balance, bool isLow = false}) {
  return BalanceSummary(
    operatorCode: 'OM',
    operatorName: 'Orange Money',
    phoneNumber: '0701234234',
    balance: balance,
    isLow: isLow,
    alertThreshold: 50000,
    lastUpdated: DateTime(2024, 1, 15),
  );
}

AgentSummary _summary(List<BalanceSummary> balances) {
  return AgentSummary(
    agentCode: 'AGT-0042',
    agentName: 'Kone Moussa',
    totalBalance: balances.fold(0, (s, b) => s + b.balance),
    benefits: const BenefitPeriod(today: 0, week: 0, month: 0, total: 0),
    balances: balances,
    transactionCountToday: 0,
  );
}

void main() {
  group('AgentSummary', () {
    test('agentInitials prend les initiales prenom + nom', () {
      expect(_summary(const []).agentInitials, 'KM');
    });

    test('activeSimCount = nombre de puces', () {
      final s = _summary([_balance(balance: 1000), _balance(balance: 2000)]);
      expect(s.activeSimCount, 2);
    });

    test('hasLowBalance true si une puce est faible ou vide', () {
      final s = _summary([
        _balance(balance: 200000),
        _balance(balance: 10000, isLow: true),
      ]);
      expect(s.hasLowBalance, isTrue);
    });

    test('hasLowBalance false si toutes les puces sont OK', () {
      final s = _summary([_balance(balance: 200000)]);
      expect(s.hasLowBalance, isFalse);
    });
  });
}
