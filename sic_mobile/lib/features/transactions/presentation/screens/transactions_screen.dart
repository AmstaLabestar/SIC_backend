import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/widgets/pressable.dart';

/// Type d'operation (Phase 2 : donnees mockees).
enum _TxnType { depot, retrait, transfert, recharge }

class _Txn {
  const _Txn({
    required this.type,
    required this.operator,
    required this.amount,
    required this.time,
  });

  final _TxnType type;
  final String operator;
  final double amount;
  final String time;
}

const _mockTxns = <_Txn>[
  _Txn(type: _TxnType.depot, operator: 'Orange Money', amount: 50000, time: 'Il y a 12 min'),
  _Txn(type: _TxnType.retrait, operator: 'Moov Money', amount: 25000, time: 'Il y a 1 h'),
  _Txn(type: _TxnType.transfert, operator: 'OM -> Telecel', amount: 30000, time: 'Il y a 3 h'),
  _Txn(type: _TxnType.recharge, operator: 'Telecel Money', amount: 5000, time: 'Aujourd\'hui, 09:14'),
  _Txn(type: _TxnType.depot, operator: 'Orange Money', amount: 120000, time: 'Hier, 18:02'),
  _Txn(type: _TxnType.retrait, operator: 'Moov Money', amount: 40000, time: 'Hier, 11:37'),
];

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _TxnType? _filter; // null = tout

  @override
  Widget build(BuildContext context) {
    final txns = _filter == null
        ? _mockTxns
        : _mockTxns.where((t) => t.type == _filter).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transactions', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Historique de vos operations.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Filters(selected: _filter, onChanged: (f) => setState(() => _filter = f))),
          if (txns.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _Empty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList.separated(
                itemCount: txns.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _TxnTile(txn: txns[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onChanged});

  final _TxnType? selected;
  final ValueChanged<_TxnType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <(_TxnType?, String)>[
      (null, 'Tout'),
      (_TxnType.depot, 'Depots'),
      (_TxnType.retrait, 'Retraits'),
      (_TxnType.transfert, 'Transferts'),
      (_TxnType.recharge, 'Recharges'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (type, label) = chips[index];
          final active = type == selected;
          return Pressable(
            onTap: () => onChanged(type),
            pressedScale: 0.95,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: active ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});

  final _Txn txn;

  @override
  Widget build(BuildContext context) {
    final visual = _TxnVisual.of(txn.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.soft(visual.color),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(visual.icon, color: visual.color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visual.label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${txn.operator} · ${txn.time}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${visual.sign}${FcfaFormatter.format(txn.amount)}',
            style: AppTextStyles.caption.copyWith(
              color: visual.amountColor,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnVisual {
  const _TxnVisual({
    required this.label,
    required this.icon,
    required this.color,
    required this.sign,
    required this.amountColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String sign;
  final Color amountColor;

  factory _TxnVisual.of(_TxnType type) {
    return switch (type) {
      _TxnType.depot => const _TxnVisual(
          label: 'Depot',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.secondary,
          sign: '+ ',
          amountColor: AppColors.secondary,
        ),
      _TxnType.retrait => const _TxnVisual(
          label: 'Retrait',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.primaryLight,
          sign: '- ',
          amountColor: AppColors.danger,
        ),
      _TxnType.transfert => const _TxnVisual(
          label: 'Transfert',
          icon: Icons.swap_horiz_rounded,
          color: Color(0xFF534AB7),
          sign: '- ',
          amountColor: AppColors.textPrimary,
        ),
      _TxnType.recharge => const _TxnVisual(
          label: 'Recharge',
          icon: Icons.phone_android_rounded,
          color: AppColors.secondary,
          sign: '- ',
          amountColor: AppColors.textPrimary,
        ),
    };
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primaryLight,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Aucune transaction', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Aucune operation pour ce filtre.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
