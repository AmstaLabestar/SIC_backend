import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/widgets/operator_logo.dart';
import '../../domain/entities/sim_card.dart';

class SimCardTile extends StatelessWidget {
  const SimCardTile({
    super.key,
    required this.sim,
    required this.onToggle,
    required this.onEditThreshold,
  });

  final SimCard sim;
  final VoidCallback onToggle;
  final VoidCallback onEditThreshold;

  @override
  Widget build(BuildContext context) {
    final status = _SimStatus.fromSim(sim);

    return Dismissible(
      key: ValueKey(sim.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onToggle();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: sim.isActive ? AppColors.danger : AppColors.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          sim.isActive ? 'Desactiver' : 'Activer',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.surface),
        ),
      ),
      child: Opacity(
        opacity: sim.isActive ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              OperatorLogo(operatorCode: sim.operatorCode),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sim.operatorName,
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!sim.isActive) const _InactiveBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_maskPhone(sim.phoneNumber), style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          status.label,
                          style: AppTextStyles.caption.copyWith(
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FcfaFormatter.format(sim.balance),
                    style: AppTextStyles.amountSmall,
                  ),
                  IconButton(
                    tooltip: 'Modifier le seuil',
                    onPressed: onEditThreshold,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _maskPhone(String phoneNumber) {
    if (phoneNumber.length < 6) {
      return phoneNumber;
    }

    return '${phoneNumber.substring(0, 2)}***${phoneNumber.substring(
      phoneNumber.length - 3,
    )}';
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('Inactif', style: AppTextStyles.caption),
    );
  }
}

class _SimStatus {
  const _SimStatus({required this.label, required this.color});

  final String label;
  final Color color;

  factory _SimStatus.fromSim(SimCard sim) {
    if (!sim.isActive) {
      return const _SimStatus(label: 'Inactive', color: AppColors.textSecondary);
    }

    if (sim.isEmpty) {
      return const _SimStatus(label: 'Vide', color: AppColors.danger);
    }

    if (sim.isLow) {
      return const _SimStatus(label: 'Faible', color: AppColors.warning);
    }

    return const _SimStatus(label: 'OK', color: AppColors.success);
  }
}
