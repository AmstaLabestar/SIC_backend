import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/preferences/privacy_provider.dart';
import 'package:sic_mobile/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Sans box Hive ouverte, la preference defaut a `false` (soldes visibles), et
/// la visibilite hero/SIM suit `!hideBalances`.
void main() {
  test('defaut : soldes visibles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hideBalancesProvider), isFalse);
    expect(container.read(heroBalanceVisibleProvider), isTrue);
    expect(container.read(simVisibilityProvider('OM')), isTrue);
  });

  test('activer "masquer les soldes" masque hero + SIM par defaut', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(hideBalancesProvider.notifier).set(true);

    expect(container.read(hideBalancesProvider), isTrue);
    expect(container.read(heroBalanceVisibleProvider), isFalse);
    expect(container.read(simVisibilityProvider('OM')), isFalse);
  });
}
