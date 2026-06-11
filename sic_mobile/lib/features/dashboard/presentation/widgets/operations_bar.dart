import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/pressable.dart';

/// Une operation principale.
class Operation {
  const Operation({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

/// Barre segmentee epuree : toutes les operations principales visibles d'un
/// coup (pas de scroll), separees par de fins traits, dans un seul conteneur.
class OperationsBar extends StatelessWidget {
  const OperationsBar({super.key, required this.operations});

  final List<Operation> operations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            for (var i = 0; i < operations.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.border,
                ),
              Expanded(child: _Segment(operation: operations[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.operation});

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: operation.onTap,
      pressedScale: 0.94,
      haptic: HapticType.medium,
      semanticLabel: operation.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(operation.icon, color: operation.color, size: 26),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                operation.label,
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
