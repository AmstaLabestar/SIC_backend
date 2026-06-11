import 'dart:ui';

/// Palette officielle SIC — basee sur le mockup dashboard valide par le client.
class AppColors {
  const AppColors._();

  // Marque
  static const primary = Color(0xFF1A3C6E); // nav actif, bottom nav
  static const primaryLight = Color(0xFF2356A8); // gradient hero, liens, retrait
  static const primaryBg = Color(0xFFEBF1FA); // fond cards actions bleu
  static const secondary = Color(0xFF1B8C5E); // depot, avatar, recharge
  static const secondaryBg = Color(0xFFE8F5EF); // fond cards actions vert

  // Etats
  static const success = Color(0xFF22C97A); // gain, statut OK, pip nav
  static const warning = Color(0xFFF59E0B); // solde faible, fond card jaune
  static const danger = Color(0xFFEF4444); // solde vide, badge alerte

  // Surfaces
  static const background = Color(0xFFF4F7FC); // fond general app
  static const surface = Color(0xFFFFFFFF); // fond cards
  static const surfaceLow = Color(0xFFFFFDE7); // fond card SIM solde faible

  // Texte
  static const textPrimary = Color(0xFF0D1B2A); // titres, montants, labels
  static const textSecondary = Color(0xFF64748B); // sous-titres, numeros SIM
  static const textTertiary = Color(0xFF94A3B8); // nav inactif, placeholders
  static const onPrimary = Color(0xFFFFFFFF);

  // Bordures
  static const border = Color(0xFFDCE6F0); // bordures legeres
  static const cardBorder = border; // alias historique

  // --- Alias de compatibilite (anciens tokens encore references) ---
  static const accent = warning;
  static const emerald = secondary;
  static const gradientStart = primary;
  static const gradientMid = primaryLight;
  static const gradientEnd = secondary;
  static const surfaceMuted = primaryBg;
}
