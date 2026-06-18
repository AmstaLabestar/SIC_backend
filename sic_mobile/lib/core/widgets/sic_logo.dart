import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_radii.dart';

/// Logo de marque SIC presente dans une tuile blanche arrondie avec une ombre
/// douce. Le visuel source etant un JPEG a fond blanc (sans transparence), la
/// tuile blanche permet un fondu propre sur n'importe quel fond de l'app.
class SicLogo extends StatelessWidget {
  const SicLogo({super.key, this.size = 88, this.radius, this.elevated = true});

  final double size;
  final double? radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadii.md;
    return Container(
      height: size,
      width: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Image.asset(
          AppAssets.logoLight,
          fit: BoxFit.contain,
          // Repli discret si l'asset manque (build sans images).
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
