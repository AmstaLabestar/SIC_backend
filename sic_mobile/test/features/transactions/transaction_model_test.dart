import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/transactions/data/models/agent_transaction_model.dart';
import 'package:sic_mobile/features/transactions/data/models/operation_result_model.dart';
import 'package:sic_mobile/features/transactions/domain/entities/agent_transaction.dart';

void main() {
  group('AgentTransactionModel.fromJson', () {
    test('mappe le type DEPOT et l\'operateur ORANGE -> OM', () {
      final t = AgentTransactionModel.fromJson({
        'id': 'tx-1',
        'type': 'DEPOT',
        'status': 'PENDING',
        'target_operator': 'ORANGE',
        'target_phone_number': '07000001',
        'amount': '5000.00',
        'commission_sic': '50.00',
        'agent_benefit': '120.00',
        'is_compensated': false,
        'created_at': '2026-06-12T10:00:00Z',
      });

      expect(t.kind, TransactionKind.deposit);
      expect(t.status, 'PENDING');
      expect(t.amount, 5000);
      expect(t.commissionSic, 50);
      expect(t.operatorCode, 'OM');
      expect(t.operatorName, 'Orange Money');
      expect(t.isPending, isTrue);
    });

    test('mappe RETRAIT et SWAP', () {
      expect(
        AgentTransactionModel.fromJson({'type': 'RETRAIT'}).kind,
        TransactionKind.withdrawal,
      );
      expect(
        AgentTransactionModel.fromJson({'type': 'SWAP'}).kind,
        TransactionKind.transfer,
      );
    });

    test('type inconnu -> other, valeurs par defaut robustes', () {
      final t = AgentTransactionModel.fromJson({'type': 'XYZ'});
      expect(t.kind, TransactionKind.other);
      expect(t.amount, 0);
      expect(t.operatorCode, isNull);
    });
  });

  group('OperationResultModel.fromJson', () {
    test('depot : commission/benefice presents', () {
      final r = OperationResultModel.fromJson({
        'transaction_id': 'tx-9',
        'amount': '5000',
        'commission_sic': '50',
        'status': 'PENDING',
        'created_at': '2026-06-12T10:00:00Z',
      });
      expect(r.transactionId, 'tx-9');
      expect(r.amount, 5000);
      expect(r.commissionSic, 50);
      expect(r.status, 'PENDING');
    });

    test('transfert : commission absente -> null', () {
      final r = OperationResultModel.fromJson({
        'transaction_id': 'tx-10',
        'amount': '2000',
        'status': 'PENDING',
        'created_at': '2026-06-12T10:00:00Z',
      });
      expect(r.commissionSic, isNull);
    });
  });
}
