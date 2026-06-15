import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/widgets/pressable.dart';

/// Hero Card — carte du solde total (mockup valide).
///
/// Gradient bleu -> bleu -> vert (145deg), cercles decoratifs, montant en
/// CountUp, pill du volume compense du jour, et bouton oeil pour masquer le solde.
/// L'etat de visibilite est gere par le parent (Riverpod).
class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.totalBalance,
    required this.todayCompensated,
    required this.activeSimCount,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  final double totalBalance;
  final double todayCompensated;
  final int activeSimCount;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppGradients.hero,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned(top: -50, right: -40, child: _Circle(160, 0.05)),
            const Positioned(
              bottom: -40,
              left: 60,
              child: _Circle(120, 0.08, color: AppColors.success),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Solde total · $activeSimCount SIM actives',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _Amount(amount: totalBalance, isVisible: isVisible)),
                    const SizedBox(width: AppSpacing.sm),
                    _EyeButton(isVisible: isVisible, onTap: onToggleVisibility),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _CompensationPill(amount: todayCompensated),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.amount, required this.isVisible});

  final double amount;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: isVisible
          ? TweenAnimationBuilder<double>(
              key: const ValueKey('visible'),
              tween: Tween<double>(begin: 0, end: amount),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => _AmountText(value: value),
            )
          : ImageFiltered(
              key: const ValueKey('hidden'),
              imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Opacity(
                opacity: 0.5,
                child: _AmountText(value: amount),
              ),
            ),
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final number = FcfaFormatter.format(value).replaceFirst(' FCFA', '');

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        maxLines: 1,
        text: TextSpan(
          text: number,
          style: AppTextStyles.heroAmount,
          children: [
            TextSpan(
              text: '  FCFA',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.isVisible, required this.onTap});

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      haptic: HapticType.light,
      semanticLabel: isVisible ? 'Masquer le solde' : 'Afficher le solde',
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onPrimary.withValues(alpha: 0.15),
        ),
        child: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off,
          color: AppColors.onPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _CompensationPill extends StatelessWidget {
  const _CompensationPill({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horiz_rounded,
              color: AppColors.onPrimary, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${FcfaFormatter.format(amount)} compense aujourd\'hui',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle(this.size, this.opacity, {this.color = AppColors.onPrimary});

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
