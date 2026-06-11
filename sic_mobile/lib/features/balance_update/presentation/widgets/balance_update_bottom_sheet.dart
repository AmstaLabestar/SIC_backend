import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_amount_display.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../dashboard/domain/entities/balance_summary.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/balance_update.dart';
import '../../domain/usecases/update_balance.dart';
import '../providers/balance_update_provider.dart';

class BalanceUpdateBottomSheet extends ConsumerStatefulWidget {
  const BalanceUpdateBottomSheet({super.key, required this.balance});

  final BalanceSummary balance;

  static Future<void> show(BuildContext context, BalanceSummary balance) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BalanceUpdateBottomSheet(balance: balance),
    );
  }

  @override
  ConsumerState<BalanceUpdateBottomSheet> createState() {
    return _BalanceUpdateBottomSheetState();
  }
}

class _BalanceUpdateBottomSheetState
    extends ConsumerState<BalanceUpdateBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newBalanceController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _newBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(
      balanceHistoryProvider(widget.balance.operatorCode),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actualiser le solde ${widget.balance.operatorName}',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              _CurrentBalancePanel(balance: widget.balance),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _newBalanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nouveau solde',
                  suffixText: 'FCFA',
                ),
                validator: Validators.validateAmount,
              ),
              const SizedBox(height: AppSpacing.lg),
              _HistorySection(historyState: historyState),
              const SizedBox(height: AppSpacing.lg),
              SicButton(
                label: 'Confirmer',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final newBalance = double.parse(_newBalanceController.text);
    final usecase = ref.read(updateBalanceProvider);
    final result = await usecase(
      UpdateBalanceParams(
        operatorCode: widget.balance.operatorCode,
        previousBalance: widget.balance.balance,
        newBalance: newBalance,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (update) {
        HapticFeedback.mediumImpact();
        ref.read(dashboardNotifierProvider.notifier).applyBalanceUpdate(
              operatorCode: update.operatorCode,
              newBalance: update.newBalance,
              updatedAt: update.updatedAt,
            );
        ref.invalidate(balanceHistoryProvider(widget.balance.operatorCode));
        Navigator.of(context).pop();
      },
    );
  }
}

class _CurrentBalancePanel extends StatelessWidget {
  const _CurrentBalancePanel({required this.balance});

  final BalanceSummary balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solde actuel', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          SicAmountDisplay(
            amount: balance.balance,
            size: SicAmountSize.medium,
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.historyState});

  final AsyncValue<List<BalanceUpdate>> historyState;

  @override
  Widget build(BuildContext context) {
    return historyState.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stackTrace) => Text(
        'Historique indisponible',
        style: AppTextStyles.caption,
      ),
      data: (history) {
        final visibleHistory = history.take(3).toList();

        if (visibleHistory.isEmpty) {
          return Text(
            'Aucune mise a jour recente',
            style: AppTextStyles.caption,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dernieres mises a jour',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...visibleHistory.map(
              (update) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormatter.formatRelative(update.updatedAt),
                        style: AppTextStyles.caption,
                      ),
                    ),
                    Text(
                      FcfaFormatter.format(update.newBalance),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
