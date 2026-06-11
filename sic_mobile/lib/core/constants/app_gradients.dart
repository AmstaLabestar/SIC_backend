import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Gradients du design system.
///
/// Le gradient principal (bleu -> emeraude) est reserve a la piece maitresse :
/// la carte solde. Les autres sont des teintes douces pour les fonds d'icones.
class AppGradients {
  const AppGradients._();

  /// Gradient principal de la carte solde.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
  );

  /// Teinte douce d'une couleur (fond d'icone d'action rapide).
  static LinearGradient soft(Color color) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: 0.16),
        color.withValues(alpha: 0.04),
      ],
    );
  }
}
