import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/network/network_providers.dart';
import 'package:sic_mobile/core/storage/token_storage.dart';
import 'package:sic_mobile/features/auth/presentation/screens/register_screen.dart';

/// Stockage de tokens vide (pas de plugin natif en test).
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
      child: const MaterialApp(home: RegisterScreen()),
    );

void main() {
  testWidgets(
      'le champ Code marchand est visible pour un Agent, masque pour un Client',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // Agent est selectionne par defaut -> champ code marchand present.
    expect(find.text('Code marchand'), findsOneWidget);

    // Bascule sur Client -> le champ disparait.
    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();
    expect(find.text('Code marchand'), findsNothing);

    // Retour sur Agent -> le champ revient.
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    expect(find.text('Code marchand'), findsOneWidget);
  });
}
