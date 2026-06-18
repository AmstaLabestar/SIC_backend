import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/alerts/data/datasources/alert_remote_datasource.dart';

/// Verifie le mapping JSON backend -> modele et le corps du PATCH.
void main() {
  late List<RequestOptions> captured;
  late AlertRemoteDatasource datasource;

  Dio buildDio(Object responseData) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: responseData,
        ));
      },
    ));
    return dio;
  }

  setUp(() => captured = []);

  test('getAlertConfigs mappe results et traduit ORANGE -> OM', () async {
    datasource = AlertRemoteDatasource(buildDio({
      'count': 1,
      'results': [
        {
          'id': 'cfg-1',
          'puce_id': 'puce-1',
          'operator': 'ORANGE',
          'phone_number': '+22670000001',
          'balance': '100000.00',
          'threshold': 50000,
          'is_enabled': true,
          'updated_at': '2026-06-18T10:00:00Z',
        }
      ],
    }));

    final configs = await datasource.getAlertConfigs();

    expect(configs, hasLength(1));
    expect(configs.single.operatorCode, 'OM');
    expect(configs.single.operatorName, 'Orange Money');
    expect(configs.single.phoneNumber, '+22670000001');
    expect(configs.single.threshold, 50000);
    expect(captured.single.path, '/alerts/');
    expect(captured.single.method, 'GET');
  });

  test('updateAlertConfig PATCH /alerts/{id}/ avec seuil + activation', () async {
    datasource = AlertRemoteDatasource(buildDio({
      'id': 'cfg-1',
      'puce_id': 'puce-1',
      'operator': 'MOOV',
      'phone_number': '+22670000002',
      'balance': '0.00',
      'threshold': 75000,
      'is_enabled': false,
      'updated_at': '2026-06-18T11:00:00Z',
    }));

    final config = await datasource.updateAlertConfig(
      id: 'cfg-1',
      threshold: 75000,
      isEnabled: false,
    );

    expect(captured.single.method, 'PATCH');
    expect(captured.single.path, '/alerts/cfg-1/');
    final body = captured.single.data as Map<String, dynamic>;
    expect(body['threshold'], 75000);
    expect(body['is_enabled'], false);
    expect(config.threshold, 75000);
    expect(config.isEnabled, isFalse);
  });
}
