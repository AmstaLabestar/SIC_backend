import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/network/network_providers.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/main.dart';

/// Stockage en memoire pour eviter le plugin natif (channels) en test.
class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage() : super(_noopStorage);
  static const _noopStorage = FlutterSecureStorage();

  String? _access;
  String? _refresh;

  @override
  Future<bool> hasSession() async => _refresh != null;

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> saveAccess(String access) async => _access = access;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

void main() {
  testWidgets('should route to login when no session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const SicMobileApp(),
      ),
    );

    // Splash -> verification de session (pas de token) -> redirection login.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);
  });
}
