import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/errors/failures.dart';
import 'package:sic_mobile/features/transactions/domain/entities/agent_transaction.dart';
import 'package:sic_mobile/features/transactions/domain/entities/operation_result.dart';
import 'package:sic_mobile/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:sic_mobile/features/transactions/presentation/providers/transaction_providers.dart';

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository({this.failure, this.list = const []});

  final Failure? failure;
  final List<AgentTransaction> list;
  final List<String> calls = [];

  @override
  Future<Either<Failure, List<AgentTransaction>>> getTransactions() async {
    if (failure != null) return Left(failure!);
    return Right(list);
  }

  @override
  Future<Either<Failure, OperationResult>> deposit({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
  }) async {
    calls.add('deposit:$amount:$operatorCode:$phoneNumber');
    return _result(amount);
  }

  @override
  Future<Either<Failure, OperationResult>> withdraw({
    required double amount,
    required String operatorCode,
    required String phoneNumber,
  }) async {
    calls.add('withdraw:$amount:$operatorCode:$phoneNumber');
    return _result(amount);
  }

  @override
  Future<Either<Failure, OperationResult>> convert({
    required double amount,
    required String sourcePuceId,
    required String targetPuceId,
  }) async {
    calls.add('convert:$amount:$sourcePuceId:$targetPuceId');
    return _result(amount);
  }

  Either<Failure, OperationResult> _result(double amount) {
    if (failure != null) return Left(failure!);
    return Right(OperationResult(
      transactionId: 'tx-1',
      amount: amount,
      status: 'PENDING',
      createdAt: DateTime(2026, 6, 12),
    ));
  }
}

AgentTransaction _txn(TransactionKind kind) => AgentTransaction(
      id: 'x',
      kind: kind,
      status: 'PENDING',
      amount: 1000,
      commissionSic: 0,
      agentBenefit: 0,
      createdAt: DateTime(2026, 6, 12),
    );

void main() {
  test('historique : charge la liste via le repo', () async {
    final repo = _FakeTransactionRepository(
      list: [_txn(TransactionKind.deposit), _txn(TransactionKind.transfer)],
    );
    final container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final txns = await container.read(transactionsNotifierProvider.future);
    expect(txns, hasLength(2));
  });

  test('historique : echec -> AsyncError', () async {
    final repo = _FakeTransactionRepository(
      failure: const NetworkFailure(),
    );
    final container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(transactionsNotifierProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('deposit/withdraw/convert transmettent les bons parametres', () async {
    final repo = _FakeTransactionRepository();
    final container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final r = container.read(transactionRepositoryProvider);

    await r.deposit(amount: 5000, operatorCode: 'OM', phoneNumber: '07000001');
    await r.withdraw(amount: 3000, operatorCode: 'MOOV', phoneNumber: '70000001');
    await r.convert(amount: 2000, sourcePuceId: 'a', targetPuceId: 'b');

    expect(repo.calls, [
      'deposit:5000.0:OM:07000001',
      'withdraw:3000.0:MOOV:70000001',
      'convert:2000.0:a:b',
    ]);
  });
}
