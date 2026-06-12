import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// En-tete degrade (style hero du dashboard) partage par les ecrans PIN
/// (creation et verrouillage). [child] accueille en general des [PinDots].
class PinGradientHeader extends StatelessWidget {
  const PinGradientHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
    this.showBack = false,
    this.onBack,
    this.subtitleError = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;
  final bool showBack;
  final VoidCallback? onBack;
  final bool subtitleError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showBack
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.onPrimary),
                          onPressed: onBack,
                        )
                      : null,
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: AppColors.onPrimary, size: 28),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.onPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: subtitleError
                      ? const Color(0xFFFFD2D2)
                      : AppColors.onPrimary.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              if (child != null) ...[
                const SizedBox(height: AppSpacing.lg),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Banniere d'erreur (fond rouge clair) partagee par les ecrans PIN.
class PinErrorBanner extends StatelessWidget {
  const PinErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
