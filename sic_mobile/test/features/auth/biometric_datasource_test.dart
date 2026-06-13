import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/auth/data/datasources/biometric_remote_datasource.dart';

/// Verifie le contrat reseau biometrique : champs envoyes a register/login et
/// parsing des jetons. Timestamp en SECONDES (sinon la signature backend casse).
void main() {
  late List<RequestOptions> captured;
  late BiometricRemoteDatasource datasource;

  setUp(() {
    captured = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options);
        final isLogin = options.path.contains('login');
        handler.resolve(Response(
          requestOptions: options,
          statusCode: isLogin ? 200 : 201,
          data: isLogin
              ? {
                  'message': 'ok',
                  'access': 'access-jwt',
                  'refresh': 'refresh-jwt',
                  'agent_id': 'a1',
                  'first_name': 'M',
                }
              : {'message': 'ok', 'device_id': 'dev-1'},
        ));
      },
    ));
    datasource = BiometricRemoteDatasource(dio);
  });

  test('register envoie device_id / device_name / public_key', () async {
    await datasource.register(
      deviceId: 'dev-1',
      deviceName: 'Android',
      publicKey: '-----BEGIN PUBLIC KEY-----\nABC\n-----END PUBLIC KEY-----',
    );

    final body = captured.single.data as Map;
    expect(captured.single.path, contains('/auth/biometric/register/'));
    expect(body['device_id'], 'dev-1');
    expect(body['device_name'], 'Android');
    expect(body['public_key'], startsWith('-----BEGIN PUBLIC KEY-----'));
  });

  test('login envoie device_id / signature / timestamp et parse les jetons',
      () async {
    final tokens = await datasource.login(
      deviceId: 'dev-1',
      signature: 'sig-b64',
      timestamp: 1750000000,
    );

    final body = captured.single.data as Map;
    expect(captured.single.path, contains('/auth/biometric/login/'));
    expect(body['device_id'], 'dev-1');
    expect(body['signature'], 'sig-b64');
    expect(body['timestamp'], 1750000000);
    // En secondes : pas une valeur en millisecondes.
    expect(body['timestamp'], lessThan(1000000000000));
    expect(tokens.access, 'access-jwt');
    expect(tokens.refresh, 'refresh-jwt');
  });
}
