import 'package:flutter/material.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/models/agent.dart';

/// Balance Card Widget - Shows total balance with gradient
class BalanceCard extends StatelessWidget {
  final double totalBalance;
  final Agent? agent;
  final VoidCallback? onTap;
  final bool isLoading;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    this.agent,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SicTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: SicTheme.primaryGradient,
        borderRadius: BorderRadius.circular(SicTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solde Total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
              if (agent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SicTheme.spaceSm,
                    vertical: SicTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vérifié',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: SicTheme.spaceSm),

          // Balance
          isLoading
              ? const SizedBox(
                  height: 36,
                  width: 150,
                  child: LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  Formatters.currency(totalBalance),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                ),

          const SizedBox(height: SicTheme.spaceMd),

          // Quick info
          if (agent != null && agent!.puces != null) ...[
            Text(
              '${agent!.puces!.length} puce${agent!.puces!.length > 1 ? 's' : ''} active${agent!.puces!.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Puce Card Widget - Shows a SIM card with balance
class PuceCard extends StatelessWidget {
  final Puce puce;
  final VoidCallback? onTap;
  final bool showFullDetails;

  const PuceCard({
    super.key,
    required this.puce,
    this.onTap,
    this.showFullDetails = true,
  });

  Color _getOperatorColor() {
    return Color(Formatters.operatorColor(puce.operator));
  }

  IconData _getOperatorIcon() {
    switch (puce.operator.toUpperCase()) {
      case 'ORANGE':
        return Icons.circle;
      case 'MOOV':
        return Icons.signal_cellular_alt;
      case 'TELECEL':
        return Icons.cell_tower;
      case 'CORIS':
        return Icons.wifi;
      default:
        return Icons.sim_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorColor = _getOperatorColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: SicTheme.spaceSm),
      child: Material(
        color: isDark ? SicTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(SicTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SicTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(SicTheme.spaceMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SicTheme.radiusLg),
              border: Border.all(
                color: isDark ? SicTheme.surfaceLightDark : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                // Operator icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: operatorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SicTheme.radiusMd),
                  ),
                  child: Center(
                    child: Icon(
                      _getOperatorIcon(),
                      color: operatorColor,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: SicTheme.spaceMd),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            Formatters.operatorLabel(puce.operator),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: puce.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.phoneNumber(puce.phoneNumber),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(puce.balance),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: operatorColor,
                          ),
                    ),
                    if (showFullDetails)
                      Text(
                        'Solde',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                  ],
                ),

                const SizedBox(width: SicTheme.spaceSm),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transaction Tile Widget - Shows a transaction item
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  IconData _getTypeIcon() {
    switch (transaction.type.toUpperCase()) {
      case 'DEPOT':
        return Icons.arrow_downward;
      case 'RETRAIT':
        return Icons.arrow_upward;
      case 'TRANSFERT':
        return Icons.swap_horiz;
      case 'SWAP':
        return Icons.swap_horiz;
      default:
        return Icons.receipt;
    }
  }

  Color _getStatusColor() {
    return Color(Formatters.statusColor(transaction.status));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeposit = transaction.isDeposit;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: SicTheme.spaceSm),
      child: Material(
        color: isDark ? SicTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SicTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(SicTheme.spaceMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SicTheme.radiusMd),
              border: Border.all(
                color: isDark ? SicTheme.surfaceLightDark : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDeposit ? Colors.green : primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SicTheme.radiusSm),
                  ),
                  child: Center(
                    child: Icon(
                      _getTypeIcon(),
                      color: isDeposit ? Colors.green : primaryColor,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: SicTheme.spaceMd),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.typeLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.operatorLabel(transaction.targetOperator)} • ${Formatters.relativeDateTime(transaction.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Amount & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDeposit ? '+' : '-'}${Formatters.currency(transaction.amount)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? Colors.green : primaryColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick Action Button
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(SicTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SicTheme.spaceMd,
            vertical: SicTheme.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(SicTheme.radiusMd),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: SicTheme.spaceSm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}