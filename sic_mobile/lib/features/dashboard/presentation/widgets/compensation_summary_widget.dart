import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_amount_display.dart';
import '../../domain/entities/agent_summary.dart';
import '../providers/dashboard_provider.dart';

/// Volume d'operations sauvees par la compensation, pour la periode choisie
/// (lot C4). Mesure d'activite, pas une marge de l'agent.
class CompensationSummaryWidget extends ConsumerWidget {
  const CompensationSummaryWidget({super.key, required this.summary});

  final AgentSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final amount = switch (period) {
      DashboardPeriod.today => summary.compensation.today,
      DashboardPeriod.week => summary.compensation.week,
      DashboardPeriod.month => summary.compensation.month,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Volume compense ${_label(period)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          SicAmountDisplay(
            amount: amount,
            color: AppColors.primary,
            size: SicAmountSize.medium,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0);
  }

  String _label(DashboardPeriod period) {
    return switch (period) {
      DashboardPeriod.today => 'du jour',
      DashboardPeriod.week => 'de la semaine',
      DashboardPeriod.month => 'du mois',
    };
  }
}
