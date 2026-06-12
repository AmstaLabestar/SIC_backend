import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/auth/presentation/providers/app_lock_provider.dart';

void main() {
  late ProviderContainer container;
  AppLockController lock() => container.read(appLockProvider.notifier);
  bool unlocked() => container.read(appLockProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('demarre verrouille', () {
    expect(unlocked(), isFalse);
  });

  test('unlock / lock basculent l\'etat', () {
    lock().unlock();
    expect(unlocked(), isTrue);
    lock().lock();
    expect(unlocked(), isFalse);
  });

  test('retour rapide d\'arriere-plan : reste deverrouille', () {
    lock().unlock();
    final t0 = DateTime(2026, 6, 12, 10, 0, 0);
    lock().onPaused(at: t0);
    lock().onResumed(at: t0.add(const Duration(seconds: 30)));
    expect(unlocked(), isTrue, reason: 'absence < 60s ne verrouille pas');
  });

  test('absence prolongee : reverrouille au retour', () {
    lock().unlock();
    final t0 = DateTime(2026, 6, 12, 10, 0, 0);
    lock().onPaused(at: t0);
    lock().onResumed(at: t0.add(const Duration(seconds: 90)));
    expect(unlocked(), isFalse, reason: 'absence >= 60s verrouille');
  });

  test('resume sans pause prealable n\'altere pas l\'etat', () {
    lock().unlock();
    lock().onResumed(at: DateTime(2026, 6, 12, 10, 0, 0));
    expect(unlocked(), isTrue);
  });
}
