import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

enum SicButtonVariant { primary, secondary, ghost }

class SicButton extends StatelessWidget {
  const SicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = SicButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final SicButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final isPrimary = variant == SicButtonVariant.primary;

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: label,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: isLoading ? 0.99 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isPrimary && effectiveOnPressed != null
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: switch (variant) {
              SicButtonVariant.primary => ElevatedButton(
                  onPressed: _withFeedback(effectiveOnPressed),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _ButtonContent(label: label, isLoading: isLoading),
                ),
              SicButtonVariant.secondary => OutlinedButton(
                  onPressed: _withFeedback(effectiveOnPressed),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _ButtonContent(
                    label: label,
                    isLoading: isLoading,
                    loaderColor: AppColors.primary,
                  ),
                ),
              SicButtonVariant.ghost => TextButton(
                  onPressed: _withFeedback(effectiveOnPressed),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _ButtonContent(
                    label: label,
                    isLoading: isLoading,
                    loaderColor: AppColors.primary,
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }

  VoidCallback? _withFeedback(VoidCallback? callback) {
    if (callback == null) {
      return null;
    }

    return () {
      HapticFeedback.selectionClick();
      callback();
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    this.loaderColor = AppColors.surface,
  });

  final String label;
  final bool isLoading;
  final Color loaderColor;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(
          color: loaderColor,
          strokeWidth: 2,
        ),
      );
    }

    return Text(label);
  }
}
