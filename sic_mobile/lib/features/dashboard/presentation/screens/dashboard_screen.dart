import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/sic_error_widget.dart';
import '../../../../core/widgets/sic_loading.dart';
import '../../../balance_update/presentation/widgets/balance_update_bottom_sheet.dart';
import '../../domain/entities/agent_summary.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/add_sim_sheet.dart';
import '../widgets/balance_hero_card.dart';
import '../widgets/modify_sim_sheet.dart';
import '../widgets/operations_bar.dart';
import '../widgets/sim_cards_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);

    return SafeArea(
      bottom: false,
      child: dashboardState.when(
        loading: () => const SicLoading(),
        error: (error, _) => SicErrorWidget(
          error: error,
          onRetry: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
        ),
        data: (summary) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () =>
              ref.read(dashboardNotifierProvider.notifier).refresh(),
          child: _DashboardContent(summary: summary),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.summary});

  final AgentSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBalanceVisible = ref.watch(heroBalanceVisibleProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _Header(summary: summary),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),

          // 2. Hero card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: BalanceHeroCard(
              totalBalance: summary.totalBalance,
              todayCompensated: summary.compensation.today,
              activeSimCount: summary.activeSimCount,
              isVisible: isBalanceVisible,
              onToggleVisibility: () {
                HapticFeedback.lightImpact();
                ref.read(heroBalanceVisibleProvider.notifier).update((s) => !s);
              },
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

          // 3. Operations (actions principales, sans scroll)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _SectionTitle('Operations'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: OperationsBar(
              operations: [
                Operation(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Depot',
                  color: AppColors.secondary,
                  onTap: () => context.push('/operations/depot'),
                ),
                Operation(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Retrait',
                  color: AppColors.primaryLight,
                  onTap: () => context.push('/operations/retrait'),
                ),
                Operation(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfert',
                  color: const Color(0xFF534AB7),
                  onTap: () => context.push('/operations/transfert'),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(
                begin: 0.1,
                end: 0,
              ),

          // 4. Mes SIM (wallet empile)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: SimCardsSection(
              balances: summary.balances,
              onManageTap: () => AddSimSheet.show(context),
              onCardTap: (balance) =>
                  BalanceUpdateBottomSheet.show(context, balance),
              onHistoryTap: (balance) =>
                  _comingSoon(context, 'Historique ${balance.operatorName}'),
              onModifyTap: (balance) =>
                  ModifySimSheet.show(context, balance),
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(
                begin: 0.1,
                end: 0,
              ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$label — bientot disponible.'),
        ),
      );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final AgentSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar -> acces parametres.
        Pressable(
          onTap: () => context.go('/dashboard/settings'),
          semanticLabel: 'Profil et parametres',
          child: Container(
            height: 52,
            width: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
            child: Text(summary.agentInitials, style: AppTextStyles.avatarInitials),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour 👋', style: AppTextStyles.caption),
              Text(
                summary.agentName,
                style: AppTextStyles.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.chat_bubble_outline,
          tooltip: 'Messages',
          onTap: () => _comingSoon(context, 'Messages'),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.insights_rounded,
          tooltip: 'Statistiques',
          onTap: () => context.go('/dashboard/stats'),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          hasBadge: summary.hasUnreadNotifications,
          onTap: () => context.go('/dashboard/alerts'),
        ),
      ],
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$label — bientot disponible.'),
        ),
      );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            if (hasBadge)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
