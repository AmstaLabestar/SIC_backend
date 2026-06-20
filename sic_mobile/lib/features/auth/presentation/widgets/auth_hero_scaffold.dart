import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/sic_logo.dart';

/// Ossature premium des ecrans d'authentification : un en-tete degrade de marque
/// (logo + titre + sous-titre en blanc) surmonte d'une feuille blanche aux coins
/// arrondis qui chevauche legerement le degrade, ou se loge le formulaire.
///
/// Partage par login et inscription pour une experience unifiee et coherente
/// avec les ecrans OTP/PIN (memes codes visuels).
class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.onBack,
  });

  final String title;

  /// Rendu en blanc (DefaultTextStyle) : passer un simple `Text` sans couleur,
  /// ou un `AnimatedSwitcher` pour un sous-titre qui s'adapte (cf. inscription).
  final Widget subtitle;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Hero(
            title: title,
            subtitle: subtitle,
            showBack: showBack,
            onBack: onBack,
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final Widget subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          // Le padding bas + la translation de la feuille (-24) creent le
          // chevauchement.
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: FadeSlideIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: showBack
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: AppColors.onPrimary),
                            onPressed: onBack,
                          ),
                        )
                      : null,
                ),
                const SicLogo(size: 60),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: AppTextStyles.displayLarge
                      .copyWith(color: AppColors.onPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                DefaultTextStyle(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.88),
                  ),
                  textAlign: TextAlign.center,
                  child: subtitle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
