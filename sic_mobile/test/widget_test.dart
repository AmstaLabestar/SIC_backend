import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/main.dart';

void main() {
  testWidgets('should render dashboard with mocked summary', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SicMobileApp()));

    // Laisse le datasource mocke repondre (~800ms) puis joue les animations
    // d'entree. On evite pumpAndSettle : la banniere a un auto-scroll en boucle
    // qui ne se stabilise jamais.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Kone Moussa'), findsOneWidget);
    expect(find.textContaining('Solde total'), findsOneWidget);
    expect(find.text('Mes SIM'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.byType(TextButton), findsWidgets);
  });
}
