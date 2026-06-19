import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Nom de la box Hive des preferences applicatives (ouverte dans `main`).
const appPrefsBox = 'app_prefs';

/// Preference de confidentialite : masquer les soldes par defaut.
///
/// Persistee localement (Hive). Les soldes du dashboard (hero + SIM) s'initient
/// a `!hideBalances` ; l'oeil de chaque carte reste un affichage temporaire de
/// session. Tolerant si la box n'est pas ouverte (tests) -> defaut `false`.
final hideBalancesProvider =
    NotifierProvider<HideBalancesNotifier, bool>(HideBalancesNotifier.new);

class HideBalancesNotifier extends Notifier<bool> {
  static const _key = 'hide_balances';

  @override
  bool build() {
    if (!Hive.isBoxOpen(appPrefsBox)) return false;
    return Hive.box(appPrefsBox).get(_key, defaultValue: false) as bool;
  }

  Future<void> set(bool value) async {
    state = value;
    if (Hive.isBoxOpen(appPrefsBox)) {
      await Hive.box(appPrefsBox).put(_key, value);
    }
  }

  Future<void> toggle() => set(!state);
}
