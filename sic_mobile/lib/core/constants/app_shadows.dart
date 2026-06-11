import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Ombres diffuses et discretes (faible opacite).
///
/// Pas de grosses ombres dures : on cherche de la profondeur douce qui fait
/// flotter les surfaces au-dessus du fond.
class AppShadows {
  const AppShadows._();

  /// Ombre de carte standard.
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF1B2A4A).withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  /// Ombre encore plus legere pour petits elements (icones, chips).
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: const Color(0xFF1B2A4A).withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  /// Lueur coloree sous la carte solde principale.
  static List<BoxShadow> get hero => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.22),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
      ];

  /// Ombre flottante de la bottom navigation.
  static List<BoxShadow> get nav => [
        BoxShadow(
          color: const Color(0xFF1B2A4A).withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];
}
