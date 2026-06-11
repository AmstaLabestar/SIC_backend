import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum OperatorLogoShape { circle, roundedSquare }

/// Logo operateur — carre arrondi (ou cercle) avec gradient par operateur.
class OperatorLogo extends StatelessWidget {
  const OperatorLogo({
    super.key,
    required this.operatorCode,
    this.size = 36,
    this.shape = OperatorLogoShape.roundedSquare,
  });

  final String operatorCode;
  final double size;
  final OperatorLogoShape shape;

  @override
  Widget build(BuildContext context) {
    final config = _OperatorLogoConfig.fromCode(operatorCode);
    final borderRadius = shape == OperatorLogoShape.circle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(10);

    return Semantics(
      image: true,
      label: 'Operateur ${config.label}',
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.gradient,
          ),
          borderRadius: borderRadius,
        ),
        child: Text(
          config.shortLabel,
          style: TextStyle(
            color: config.foregroundColor,
            fontSize: size * 0.30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OperatorLogoConfig {
  const _OperatorLogoConfig({
    required this.label,
    required this.shortLabel,
    required this.gradient,
    required this.foregroundColor,
  });

  final String label;
  final String shortLabel;
  final List<Color> gradient;
  final Color foregroundColor;

  factory _OperatorLogoConfig.fromCode(String code) {
    final normalizedCode = code.toUpperCase();

    return switch (normalizedCode) {
      'OM' => const _OperatorLogoConfig(
          label: 'Orange Money',
          shortLabel: 'OM',
          gradient: [Color(0xFFFF6200), Color(0xFFFF8C42)],
          foregroundColor: AppColors.onPrimary,
        ),
      'MOOV' => const _OperatorLogoConfig(
          label: 'Moov Money',
          shortLabel: 'MV',
          gradient: [Color(0xFF0057B8), Color(0xFF2E80D8)],
          foregroundColor: AppColors.onPrimary,
        ),
      'TELECEL' => const _OperatorLogoConfig(
          label: 'Telecel Money',
          shortLabel: 'TC',
          gradient: [Color(0xFF1B8C5E), Color(0xFF22C97A)],
          foregroundColor: AppColors.onPrimary,
        ),
      'MTN' => const _OperatorLogoConfig(
          label: 'MTN Money',
          shortLabel: 'MTN',
          gradient: [Color(0xFFFFCC00), Color(0xFFFFE566)],
          foregroundColor: AppColors.textPrimary,
        ),
      'WAVE' => const _OperatorLogoConfig(
          label: 'Wave',
          shortLabel: 'WV',
          gradient: [Color(0xFF1A73E8), Color(0xFF4BA3F5)],
          foregroundColor: AppColors.onPrimary,
        ),
      'CORIS' => const _OperatorLogoConfig(
          label: 'Coris Money',
          shortLabel: 'CO',
          gradient: [Color(0xFF8B1A1A), Color(0xFFBF4040)],
          foregroundColor: AppColors.onPrimary,
        ),
      _ => _OperatorLogoConfig(
          label: normalizedCode,
          shortLabel: normalizedCode.substring(
            0,
            normalizedCode.length < 2 ? normalizedCode.length : 2,
          ),
          gradient: const [Color(0xFF64748B), Color(0xFF94A3B8)],
          foregroundColor: AppColors.onPrimary,
        ),
    };
  }
}
