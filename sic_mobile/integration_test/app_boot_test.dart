// E2E pilote (socle integration_test) — lot « plan de test §3.4 ».
//
// Lance l'app reelle sur un device/emulateur et verifie le parcours de demarrage
// bout-en-bout : boot -> verification de session (aucune) -> redirection vers
// l'ecran de connexion, avec ses champs reels.
//
// Lancement : `flutter test integration_test/` (device ou emulateur branche).
//
// Note : on injecte un stockage de tokens VIDE pour rendre le test deterministe
// (un device de test peut contenir une session residuelle). Les prochains E2E
// (login complet, envoi) brancheront un backend sandbox.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sic_mobile/core/network/network_providers.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/main.dart';

/// Stockage de tokens en memoire (pas de plugin natif), session absente.
class _EmptyTokenStorage extends TokenStorage {
  _EmptyTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<String?> readAccess() async => null;

  @override
  Future<String?> readRefresh() async => null;

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {}

  @override
  Future<void> saveAccess(String access) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E — demarrage', () {
    testWidgets('boot sans session -> ecran de connexion', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
          ],
          child: const SicMobileApp(),
        ),
      );

      // Splash -> verification de session -> redirection login.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // L'ecran de connexion est bien affiche (titre + bouton).
      expect(find.text('Bienvenue'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);

      // Les champs de saisie sont presents et utilisables.
      final fields = find.byType(TextField);
      expect(fields, findsWidgets);
    });
  });
}
