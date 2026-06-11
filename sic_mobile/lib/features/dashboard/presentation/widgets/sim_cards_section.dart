import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/balance_summary.dart';
import 'sim_wallet_stack.dart';

/// Section "Mes SIM" : en-tete + pile de cartes facon Apple Wallet.
class SimCardsSection extends StatelessWidget {
  const SimCardsSection({
    super.key,
    required this.balances,
    this.onManageTap,
    this.onCardTap,
    this.onHistoryTap,
    this.onModifyTap,
  });

  final List<BalanceSummary> balances;
  final VoidCallback? onManageTap;
  final ValueChanged<BalanceSummary>? onCardTap;
  final ValueChanged<BalanceSummary>? onHistoryTap;
  final ValueChanged<BalanceSummary>? onModifyTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mes SIM', style: AppTextStyles.sectionTitle),
              const Spacer(),
              TextButton(
                onPressed: onManageTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gerer',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SimWalletStack(
            balances: balances,
            onCardTap: onCardTap,
            onHistory: onHistoryTap,
            onModify: onModifyTap,
          ),
        ],
      ),
    );
  }
}
