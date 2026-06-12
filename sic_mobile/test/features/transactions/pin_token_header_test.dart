import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/transactions/data/datasources/transaction_remote_datasource.dart';

/// Verifie que le `pin_token` (E4) part bien dans l'en-tete `X-PIN-TOKEN`
/// (regle metier : aucune operation sans code PIN).
void main() {
  late List<RequestOptions> captured;
  late TransactionRemoteDatasource datasource;

  setUp(() {
    captured = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    // Intercepte chaque requete : capture les options puis renvoie une reponse
    // canned, sans toucher le reseau.
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'transaction_id': 'tx-1',
            'amount': 5000,
            'status': 'PENDING',
            'created_at': '2026-06-12T00:00:00Z',
          },
        ));
      },
    ));
    datasource = TransactionRemoteDatasource(dio);
  });

  test('deposit avec pinToken : en-tete X-PIN-TOKEN present', () async {
    await datasource.deposit(
      amount: 5000,
      operatorCode: 'OM',
      phoneNumber: '70123456',
      pinToken: 'signed-token-123',
    );

    expect(captured.single.headers['X-PIN-TOKEN'], 'signed-token-123');
  });

  test('withdraw / convert transmettent aussi l\'en-tete', () async {
    await datasource.withdraw(
      amount: 3000,
      operatorCode: 'MOOV',
      phoneNumber: '01020304',
      pinToken: 'tok-w',
    );
    await datasource.convert(
      amount: 2000,
      sourcePuceId: 'a',
      targetPuceId: 'b',
      pinToken: 'tok-c',
    );

    expect(captured[0].headers['X-PIN-TOKEN'], 'tok-w');
    expect(captured[1].headers['X-PIN-TOKEN'], 'tok-c');
  });

  test('sans pinToken : aucun en-tete X-PIN-TOKEN', () async {
    await datasource.deposit(
      amount: 5000,
      operatorCode: 'OM',
      phoneNumber: '70123456',
    );

    expect(captured.single.headers.containsKey('X-PIN-TOKEN'), isFalse);
  });
}
