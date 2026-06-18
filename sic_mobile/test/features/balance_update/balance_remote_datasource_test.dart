import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/balance_update/data/datasources/balance_remote_datasource.dart';

/// Verifie l'appel `POST /puces/{id}/set_balance/` et l'en-tete PIN.
void main() {
  late List<RequestOptions> captured;
  late BalanceRemoteDatasource datasource;

  setUp(() {
    captured = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'message': 'Solde mis a jour', 'balance': 320000},
        ));
      },
    ));
    datasource = BalanceRemoteDatasource(dio);
  });

  test('setBalance POST le solde et l\'en-tete X-PIN-TOKEN', () async {
    final update = await datasource.setBalance(
      puceId: 'puce-1',
      newBalance: 320000,
      pinToken: 'signed-token',
    );

    expect(captured.single.method, 'POST');
    expect(captured.single.path, '/puces/puce-1/set_balance/');
    expect((captured.single.data as Map)['balance'], 320000);
    expect(captured.single.headers['X-PIN-TOKEN'], 'signed-token');
    expect(update.puceId, 'puce-1');
    expect(update.newBalance, 320000);
  });

  test('setBalance sans pinToken n\'ajoute pas d\'en-tete PIN', () async {
    await datasource.setBalance(
      puceId: 'puce-2',
      newBalance: 1000,
      pinToken: null,
    );

    expect(captured.single.headers.containsKey('X-PIN-TOKEN'), isFalse);
  });
}
