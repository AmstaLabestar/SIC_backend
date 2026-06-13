import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/services/biometric_service.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/features/auth/data/datasources/biometric_remote_datasource.dart';
import 'package:sic_mobile/features/auth/data/repositories/biometric_repository_impl.dart';

/// Authentificateur biometrique simule (les appels natifs ne sont pas testables).
class _FakeAuthenticator implements BiometricAuthenticator {
  _FakeAuthenticator({
    this.available = true,
    this.publicKey = 'PEM-PUBLIC-KEY',
    this.signature = 'SIGN-B64',
  });

  bool available;
  String? publicKey;
  String? signature;

  String? signedPayload;
  bool deleted = false;
  bool _keys = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasKeys() async => _keys;

  @override
  Future<String?> createKeys() async {
    _keys = publicKey != null;
    return publicKey;
  }

  @override
  Future<String?> sign(String payload) async {
    signedPayload = payload;
    return signature;
  }

  @override
  Future<void> deleteKeys() async {
    deleted = true;
    _keys = false;
  }

  @override
  Future<bool> prompt(String reason) async => true;
}

void main() {
  // TokenStorage s'appuie sur flutter_secure_storage : on simule son canal
  // natif par une map en memoire.
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
        case 'readAll':
          return store;
        default:
          return null;
      }
    });
  });

  /// Datasource reel branche sur un Dio qui capture les requetes et renvoie des
  /// reponses canned.
  ({BiometricRemoteDatasource ds, List<RequestOptions> captured}) buildDatasource({
    int loginStatus = 200,
  }) {
    final captured = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.add(options);
        final isLogin = options.path.contains('login');
        if (isLogin && loginStatus != 200) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: loginStatus,
              data: {'error': 'Signature invalide.'},
            ),
            type: DioExceptionType.badResponse,
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          statusCode: isLogin ? 200 : 201,
          data: isLogin
              ? {'access': 'access-jwt', 'refresh': 'refresh-jwt'}
              : {'device_id': 'x'},
        ));
      },
    ));
    return (ds: BiometricRemoteDatasource(dio), captured: captured);
  }

  test('enable : cree les cles, enregistre la cle publique, marque active',
      () async {
    final auth = _FakeAuthenticator();
    final (:ds, :captured) = buildDatasource();
    final storage = TokenStorage();
    final repo = BiometricRepositoryImpl(auth, ds, storage);

    final result = await repo.enable();

    expect(result.isRight(), isTrue);
    expect(await storage.isBiometricEnabled(), isTrue);
    final body = captured.single.data as Map;
    expect(body['public_key'], 'PEM-PUBLIC-KEY');
    expect((body['device_id'] as String).isNotEmpty, isTrue);
  });

  test('enable : biometrie indisponible -> echec sans creation de cle',
      () async {
    final auth = _FakeAuthenticator(available: false);
    final (:ds, :captured) = buildDatasource();
    final storage = TokenStorage();
    final repo = BiometricRepositoryImpl(auth, ds, storage);

    final result = await repo.enable();

    expect(result.isLeft(), isTrue);
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(captured, isEmpty);
  });

  test('enable : annulation (pas de cle) -> echec, non active', () async {
    final auth = _FakeAuthenticator(publicKey: null);
    final (:ds, :captured) = buildDatasource();
    final storage = TokenStorage();
    final repo = BiometricRepositoryImpl(auth, ds, storage);

    final result = await repo.enable();

    expect(result.isLeft(), isTrue);
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(captured, isEmpty, reason: 'aucun appel backend si annule');
  });

  test('loginWithBiometric : signe deviceId:ts (secondes), persiste les jetons',
      () async {
    final auth = _FakeAuthenticator();
    final (:ds, :captured) = buildDatasource();
    final storage = TokenStorage();
    final repo = BiometricRepositoryImpl(auth, ds, storage);

    final result = await repo.loginWithBiometric();

    expect(result.isRight(), isTrue);
    expect(await storage.readRefresh(), 'refresh-jwt');
    // Le payload signe est `deviceId:timestamp` et le timestamp envoye est
    // celui-la meme (en secondes).
    final body = captured.single.data as Map;
    final deviceId = body['device_id'] as String;
    final ts = body['timestamp'] as int;
    expect(auth.signedPayload, '$deviceId:$ts');
    expect(ts, lessThan(1000000000000));
  });

  test('loginWithBiometric : annulation -> echec, pas d\'appel reseau',
      () async {
    final auth = _FakeAuthenticator(signature: null);
    final (:ds, :captured) = buildDatasource();
    final repo = BiometricRepositoryImpl(auth, ds, TokenStorage());

    final result = await repo.loginWithBiometric();

    expect(result.isLeft(), isTrue);
    expect(captured, isEmpty);
  });

  test('loginWithBiometric : 401 -> message dedie', () async {
    final auth = _FakeAuthenticator();
    final (:ds, :captured) = buildDatasource(loginStatus: 401);
    final repo = BiometricRepositoryImpl(auth, ds, TokenStorage());

    final result = await repo.loginWithBiometric();

    expect(
      result.fold((f) => f.message, (_) => null),
      contains('Connexion biometrique echouee'),
    );
  });

  test('disable : supprime les cles et desactive', () async {
    final auth = _FakeAuthenticator();
    final (:ds, captured: _) = buildDatasource();
    final storage = TokenStorage();
    final repo = BiometricRepositoryImpl(auth, ds, storage);
    await repo.enable();

    await repo.disable();

    expect(auth.deleted, isTrue);
    expect(await storage.isBiometricEnabled(), isFalse);
  });
}
