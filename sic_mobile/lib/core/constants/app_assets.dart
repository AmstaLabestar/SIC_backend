/// Chemins centralises des assets bundles (declares dans pubspec sous
/// `assets/images/` et `assets/icons/`).
class AppAssets {
  const AppAssets._();

  /// Logo SIC (globe + libelle) sur fond clair — a poser sur une surface
  /// blanche, le fond blanc du visuel s'y fond.
  static const logoLight = 'assets/images/sic_logo_light.jpeg';

  /// Logo SIC sur fond sombre — pour les fonds fonces.
  static const logoDark = 'assets/images/sic_logo_dark.jpeg';

  /// Icone applicative (carre arrondi, fond bleu) — source pour l'icone de
  /// lancement.
  static const appIcon = 'assets/icons/app_icon.jpeg';
}
