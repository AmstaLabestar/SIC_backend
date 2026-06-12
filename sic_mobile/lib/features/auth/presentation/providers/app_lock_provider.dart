import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verrou applicatif (style Mobile Money).
///
/// `state == true` => deverrouille ; `false` => verrouille (ecran `/lock`).
/// L'etat est uniquement en memoire : a chaque ouverture a froid l'app demarre
/// verrouillee. Elle se reverrouille aussi au retour d'arriere-plan si l'absence
/// depasse [lockAfter].
class AppLockController extends Notifier<bool> {
  static const lockAfter = Duration(seconds: 60);

  DateTime? _pausedAt;

  @override
  bool build() => false; // verrouille au demarrage.

  bool get isUnlocked => state;

  /// Deverrouille apres une authentification reussie (login, setup ou PIN).
  void unlock() => state = true;

  /// Reverrouille (deconnexion, session expiree, inactivite prolongee).
  void lock() {
    if (state) state = false;
  }

  /// L'app passe en arriere-plan : on memorise l'instant.
  void onPaused({DateTime? at}) {
    _pausedAt = at ?? DateTime.now();
  }

  /// Retour au premier plan : reverrouille si l'absence depasse [lockAfter].
  void onResumed({DateTime? at}) {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;
    final now = at ?? DateTime.now();
    if (now.difference(pausedAt) >= lockAfter) {
      lock();
    }
  }
}

final appLockProvider =
    NotifierProvider<AppLockController, bool>(AppLockController.new);
