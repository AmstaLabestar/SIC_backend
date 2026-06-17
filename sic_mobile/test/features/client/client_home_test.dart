import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/network/network_providers.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/features/client/presentation/screens/client_home_screen.dart';

class _EmptyTokenStorage extends TokenStorage {
  _EmptyTokenStorage() : super(const FlutterSecureStorage());
  @override
  Future<bool> hasSession() async => false;
  @override
  Future<String?> readAccess() async => null;
  @override
  Future<String?> readRefresh() async => null;
}

Widget _harness() => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ClientHomeScreen()),
      ),
    );

void main() {
  testWidgets('l\'accueil client affiche les 3 operations et la carte SIC',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(seconds: 1)); // laisser passer les animations

    expect(find.text('Compte SIC'), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
    expect(find.text('Recharger'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets('toucher Recharger affiche un message "bientot"', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Recharger'));
    await tester.pump(); // declenche la SnackBar

    expect(find.textContaining('bientot'), findsOneWidget);
  });
}
