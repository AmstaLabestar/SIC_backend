import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_amount_display.dart';
import '../../domain/entities/agent_summary.dart';
import '../providers/dashboard_provider.dart';

class BenefitSummaryWidget extends ConsumerWidget {
  const BenefitSummaryWidget({super.key, required this.summary});

  final AgentSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedBenefitPeriodProvider);
    final amount = switch (period) {
      DashboardBenefitPeriod.today => summary.benefits.today,
      DashboardBenefitPeriod.week => summary.benefits.week,
      DashboardBenefitPeriod.month => summary.benefits.month,
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
            'Benefices ${_label(period)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          SicAmountDisplay(
            amount: amount,
            color: AppColors.success,
            size: SicAmountSize.medium,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0);
  }

  String _label(DashboardBenefitPeriod period) {
    return switch (period) {
      DashboardBenefitPeriod.today => 'du jour',
      DashboardBenefitPeriod.week => 'de la semaine',
      DashboardBenefitPeriod.month => 'du mois',
    };
  }
}
