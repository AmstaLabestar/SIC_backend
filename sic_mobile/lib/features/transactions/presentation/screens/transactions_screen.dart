import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/sic_error_widget.dart';
import '../../../../core/widgets/sic_loading.dart';
import '../../domain/entities/agent_transaction.dart';
import '../providers/transaction_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionKind? _filter; // null = tout

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsNotifierProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(transactionsNotifierProvider.notifier).refresh(),
        child: state.when(
          loading: () => const _LoadingList(),
          error: (error, _) => ListView(
            children: [
              const _Header(),
              const SizedBox(height: 80),
              SicErrorWidget(
                error: error,
                onRetry: () =>
                    ref.read(transactionsNotifierProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (all) {
            final txns = _filter == null
                ? all
                : all.where((t) => t.kind == _filter).toList();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                SliverToBoxAdapter(
                  child: _Filters(
                    selected: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ),
                if (txns.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: txns.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) =>
                          _TxnTile(txn: txns[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transactions', style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text('Historique de vos operations.', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _Header(),
        SizedBox(height: 120),
        SicLoading(),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onChanged});

  final TransactionKind? selected;
  final ValueChanged<TransactionKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <(TransactionKind?, String)>[
      (null, 'Tout'),
      (TransactionKind.deposit, 'Depots'),
      (TransactionKind.withdrawal, 'Retraits'),
      (TransactionKind.transfer, 'Transferts'),
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

  final AgentTransaction txn;

  @override
  Widget build(BuildContext context) {
    final visual = _TxnVisual.of(txn.kind);
    final subtitle = [
      (txn.operatorName != null && txn.operatorName!.isNotEmpty)
          ? txn.operatorName!
          : 'Entre puces',
      _statusLabel(txn),
      _relativeTime(txn.createdAt),
    ].join(' · ');

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
                  subtitle,
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

  String _statusLabel(AgentTransaction t) {
    if (t.isPending) return 'En attente';
    if (t.isFailed) return 'Echoue';
    if (t.isSuccess) return 'Reussi';
    return t.status;
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "a l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  factory _TxnVisual.of(TransactionKind kind) {
    return switch (kind) {
      TransactionKind.deposit => const _TxnVisual(
          label: 'Depot',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.secondary,
          sign: '+ ',
          amountColor: AppColors.secondary,
        ),
      TransactionKind.withdrawal => const _TxnVisual(
          label: 'Retrait',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.primaryLight,
          sign: '- ',
          amountColor: AppColors.danger,
        ),
      TransactionKind.transfer => const _TxnVisual(
          label: 'Transfert',
          icon: Icons.swap_horiz_rounded,
          color: Color(0xFF534AB7),
          sign: '',
          amountColor: AppColors.textPrimary,
        ),
      TransactionKind.other => const _TxnVisual(
          label: 'Operation',
          icon: Icons.receipt_long_rounded,
          color: AppColors.primaryLight,
          sign: '',
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
          Text('Vos operations apparaitront ici.',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
