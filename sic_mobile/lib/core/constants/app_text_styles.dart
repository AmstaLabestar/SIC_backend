import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typographie SIC — Inter exclusivement (fallback SF Pro Display).
///
/// La hierarchie place le solde tout en haut du poids visuel : aucun autre
/// element ne doit le dominer.
class AppTextStyles {
  const AppTextStyles._();

  /// Base Inter pour toute l'application.
  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Solde principal — poids visuel dominant.
  static TextStyle get balance => _inter(
        fontSize: 50,
        fontWeight: FontWeight.w800,
        color: AppColors.onPrimary,
        letterSpacing: -1.5,
        height: 1.0,
      );

  /// Montant de la hero card (mockup valide : 38px, blanc, w800).
  static TextStyle get heroAmount => _inter(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: AppColors.onPrimary,
        letterSpacing: -1.2,
        height: 1.0,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Initiales de l'avatar.
  static TextStyle get avatarInitials => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onPrimary,
      );

  /// Label d'action rapide.
  static TextStyle get actionLabel => _inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );

  /// Petit corps de texte (sous-titres bannieres).
  static TextStyle get bodySmall => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  /// Montant d'une carte SIM.
  static TextStyle get simAmount => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.onPrimary,
        letterSpacing: -0.8,
      );

  /// Titre de section.
  static TextStyle get sectionTitle => _inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      );

  static TextStyle get displayLarge => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      );

  static TextStyle get titleLarge => _inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  /// Nom d'operateur.
  static TextStyle get titleMedium => _inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle get bodyLarge => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodyMedium => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => _inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  /// Micro labels (statuts, actions rapides).
  static TextStyle get microLabel => _inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get amount => _inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle get amountSmall => _inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );
}
