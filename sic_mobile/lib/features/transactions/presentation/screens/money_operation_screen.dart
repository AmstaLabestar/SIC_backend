import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../sim_management/presentation/providers/sim_provider.dart';
import '../../../sim_management/presentation/widgets/operator_selector.dart';
import '../../domain/entities/operation_result.dart';
import '../providers/transaction_providers.dart';
import '../widgets/operation_success_sheet.dart';
import '../widgets/pin_prompt_sheet.dart';

/// Type d'operation sur un numero (montant + operateur + numero du destinataire).
enum MoneyOperationKind { deposit, withdraw, transfer }

/// Formulaire de depot, retrait ou envoi P2P (montant + operateur + numero cible).
class MoneyOperationScreen extends ConsumerStatefulWidget {
  const MoneyOperationScreen({super.key, required this.kind});

  final MoneyOperationKind kind;

  String get _title => switch (kind) {
        MoneyOperationKind.deposit => 'Depot',
        MoneyOperationKind.withdraw => 'Retrait',
        MoneyOperationKind.transfer => 'Envoyer',
      };

  String get _successTitle => switch (kind) {
        MoneyOperationKind.deposit => 'Depot initie',
        MoneyOperationKind.withdraw => 'Retrait initie',
        MoneyOperationKind.transfer => 'Transfert initie',
      };

  String get _ctaLabel => switch (kind) {
        MoneyOperationKind.deposit => 'Confirmer le depot',
        MoneyOperationKind.withdraw => 'Confirmer le retrait',
        MoneyOperationKind.transfer => 'Confirmer l\'envoi',
      };

  /// Libelle injecte dans la feuille PIN (« Saisissez votre PIN pour ... »).
  String get _pinActionLabel => switch (kind) {
        MoneyOperationKind.deposit => 'le depot',
        MoneyOperationKind.withdraw => 'le retrait',
        MoneyOperationKind.transfer => 'l\'envoi',
      };

  @override
  ConsumerState<MoneyOperationScreen> createState() =>
      _MoneyOperationScreenState();
}

class _MoneyOperationScreenState extends ConsumerState<MoneyOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _operatorCode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final operators = ref.read(availableOperatorsProvider);
    _operatorCode = operators.keys.isNotEmpty ? operators.keys.first : 'OM';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operators = ref.watch(availableOperatorsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget._title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
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
                validator: Validators.validateAmount,
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Operateur du destinataire', style: AppTextStyles.microLabel),
              const SizedBox(height: AppSpacing.sm),
              OperatorSelector(
                operators: operators,
                selectedOperatorCode: _operatorCode,
                onSelected: (code) => setState(() => _operatorCode = code),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Numero du destinataire', style: AppTextStyles.microLabel),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(hintText: '70123456'),
                validator: (v) =>
                    Validators.validateOperatorPhone(v, _operatorCode),
              ),
              const SizedBox(height: AppSpacing.xl),

              SicButton(
                label: widget._ctaLabel,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Regle mobile money : aucune operation sans le code PIN.
    final pinToken = await PinPromptSheet.show(
      context,
      actionLabel: widget._pinActionLabel,
    );
    if (pinToken == null || !mounted) return; // agent a annule.

    final amount = double.parse(_amountController.text.trim());
    final phone = _phoneController.text.trim();
    final repo = ref.read(transactionRepositoryProvider);

    setState(() => _isSubmitting = true);
    final result = switch (widget.kind) {
      MoneyOperationKind.deposit => await repo.deposit(
          amount: amount,
          operatorCode: _operatorCode,
          phoneNumber: phone,
          pinToken: pinToken,
        ),
      MoneyOperationKind.withdraw => await repo.withdraw(
          amount: amount,
          operatorCode: _operatorCode,
          phoneNumber: phone,
          pinToken: pinToken,
        ),
      MoneyOperationKind.transfer => await repo.transfer(
          amount: amount,
          operatorCode: _operatorCode,
          phoneNumber: phone,
          pinToken: pinToken,
        ),
    };

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
    // Les soldes ont change cote serveur : on rafraichit dashboard + historique.
    await ref.read(dashboardNotifierProvider.notifier).refresh();
    await ref.read(transactionsNotifierProvider.notifier).refresh();

    if (!mounted) return;
    await OperationSuccessSheet.show(
      context,
      title: widget._successTitle,
      result: operation,
    );

    if (mounted) Navigator.of(context).pop();
  }
}
