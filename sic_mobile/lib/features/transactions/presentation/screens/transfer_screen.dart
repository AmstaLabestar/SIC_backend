import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../dashboard/domain/entities/balance_summary.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/operation_result.dart';
import '../providers/transaction_providers.dart';
import '../widgets/operation_success_sheet.dart';
import '../widgets/pin_prompt_sheet.dart';

/// Transfert entre deux puces de l'agent (conversion / swap).
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _sourceId;
  String? _targetId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardNotifierProvider).valueOrNull;
    final puces = (summary?.balances ?? const <BalanceSummary>[])
        .where((b) => b.id != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transfert')),
      body: SafeArea(
        child: puces.length < 2
            ? _NotEnoughPuces()
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text('Depuis la puce', style: AppTextStyles.microLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _puceDropdown(
                      value: _sourceId,
                      puces: puces,
                      onChanged: (v) => setState(() {
                        _sourceId = v;
                        if (_targetId == v) _targetId = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Vers la puce', style: AppTextStyles.microLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _puceDropdown(
                      value: _targetId,
                      puces: puces.where((p) => p.id != _sourceId).toList(),
                      onChanged: (v) => setState(() => _targetId = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Montant', style: AppTextStyles.microLabel),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '5000',
                        suffixText: 'FCFA',
                      ),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SicButton(
                      label: 'Confirmer le transfert',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _puceDropdown({
    required String? value,
    required List<BalanceSummary> puces,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Choisir une puce'),
      items: [
        for (final p in puces)
          DropdownMenuItem(
            value: p.id,
            child: Text(
              '${p.operatorName} • ${p.phoneNumber} '
              '(${FcfaFormatter.format(p.balance)})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (v) => v == null ? 'Selectionnez une puce.' : null,
      onChanged: onChanged,
    );
  }

  String? _validateAmount(String? value) {
    final base = Validators.validateAmount(value);
    if (base != null) return base;
    // Verifier le solde de la puce source cote client (le backend revalide).
    final amount = double.tryParse(value!.trim()) ?? 0;
    final matches = (ref.read(dashboardNotifierProvider).valueOrNull?.balances ??
            const <BalanceSummary>[])
        .where((b) => b.id == _sourceId)
        .toList();
    if (matches.isNotEmpty && amount > matches.first.balance) {
      return 'Solde insuffisant sur la puce source.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Regle mobile money : aucune operation sans le code PIN.
    final pinToken = await PinPromptSheet.show(
      context,
      actionLabel: 'le transfert',
    );
    if (pinToken == null || !mounted) return; // agent a annule.

    final amount = double.parse(_amountController.text.trim());
    final repo = ref.read(transactionRepositoryProvider);

    setState(() => _isSubmitting = true);
    final result = await repo.convert(
      amount: amount,
      sourcePuceId: _sourceId!,
      targetPuceId: _targetId!,
      pinToken: pinToken,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    await result.fold(
      (failure) async {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(failure.message),
            ),
          );
      },
      (operation) => _onSuccess(operation),
    );
  }

  Future<void> _onSuccess(OperationResult operation) async {
    await ref.read(dashboardNotifierProvider.notifier).refresh();
    await ref.read(transactionsNotifierProvider.notifier).refresh();

    if (!mounted) return;
    await OperationSuccessSheet.show(
      context,
      title: 'Transfert initie',
      result: operation,
    );

    if (mounted) Navigator.of(context).pop();
  }
}

class _NotEnoughPuces extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Il faut au moins 2 puces pour effectuer un transfert.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
