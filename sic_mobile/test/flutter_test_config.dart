import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Configuration appliquee a TOUTE la suite de tests (Flutter charge
/// automatiquement `test/flutter_test_config.dart`).
///
/// On desactive le fetch HTTP runtime de google_fonts : sinon chaque widget
/// test qui construit un AppTextStyles (GoogleFonts.inter) declenche une
/// tentative de telechargement reseau. En test ce travail asynchrone n'aboutit
/// pas mais laisse des operations en attente qui font racer `pumpAndSettle`
/// sous execution parallele -> echecs flaky sans message d'assertion.
/// Avec le fetch desactive, les tests utilisent la police par defaut de
/// maniere deterministe.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
