import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_error_widget.dart';
import '../../../../core/widgets/sic_loading.dart';
import '../../../dashboard/domain/entities/agent_summary.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/compensation_chips.dart';
import '../../../dashboard/presentation/widgets/compensation_summary_widget.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);

    return SafeArea(
      child: dashboardState.when(
        loading: () => const SicLoading(),
        error: (error, _) => SicErrorWidget(
          error: error,
          onRetry: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
        ),
        data: (summary) => _StatsContent(summary: summary),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.summary});

  final AgentSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text('Stats', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Suivez les revenus et l activite de votre point de vente.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Volume compense'),
        const SizedBox(height: AppSpacing.md),
        const CompensationChips(),
        const SizedBox(height: AppSpacing.md),
        CompensationSummaryWidget(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _StatInfoTile(
          icon: Icons.receipt_long_outlined,
          title: 'Historique transactions',
          value: '${summary.transactionCountToday} operations aujourd hui',
          caption: 'Le detail arrive avec la phase Operations.',
        ),
        const SizedBox(height: AppSpacing.md),
        const _StatInfoTile(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Repartition par operateur',
          value: 'Analyse a venir',
          caption: 'Orange, Moov, Telecel et autres reseaux.',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.titleMedium);
  }
}

class _StatInfoTile extends StatelessWidget {
  const _StatInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(caption, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
