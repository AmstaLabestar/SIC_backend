import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/dashboard_provider.dart';

class BenefitChips extends ConsumerWidget {
  const BenefitChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedBenefitPeriodProvider);

    return Row(
      children: DashboardBenefitPeriod.values.map((period) {
        final isSelected = selectedPeriod == period;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: period == DashboardBenefitPeriod.month ? 0 : AppSpacing.sm,
            ),
            child: ChoiceChip(
              selected: isSelected,
              label: Center(child: Text(_label(period))),
              labelStyle: AppTextStyles.caption.copyWith(
                color: isSelected ? AppColors.surface : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: AppColors.primary,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.cardBorder,
              ),
              backgroundColor: AppColors.surface,
              onSelected: (_) {
                ref.read(selectedBenefitPeriodProvider.notifier).state = period;
              },
            ).animate(target: isSelected ? 1 : 0).scaleXY(
                  begin: 1,
                  end: 1.03,
                  duration: 180.ms,
                ),
          ),
        );
      }).toList(),
    );
  }

  String _label(DashboardBenefitPeriod period) {
    return switch (period) {
      DashboardBenefitPeriod.today => 'Jour',
      DashboardBenefitPeriod.week => 'Semaine',
      DashboardBenefitPeriod.month => 'Mois',
    };
  }
}
