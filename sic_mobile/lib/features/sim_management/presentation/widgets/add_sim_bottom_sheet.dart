import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/sim_provider.dart';
import 'operator_selector.dart';

class AddSimBottomSheet extends ConsumerStatefulWidget {
  const AddSimBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddSimBottomSheet(),
    );
  }

  @override
  ConsumerState<AddSimBottomSheet> createState() => _AddSimBottomSheetState();
}

class _AddSimBottomSheetState extends ConsumerState<AddSimBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedOperatorCode = 'OM';
  bool _isSaving = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operators = ref.watch(availableOperatorsProvider);

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
              Text('Ajouter une puce', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              OperatorSelector(
                operators: operators,
                selectedOperatorCode: _selectedOperatorCode,
                onSelected: (operatorCode) {
                  setState(() => _selectedOperatorCode = operatorCode);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Numero de telephone',
                  hintText: '0701234567',
                ),
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: AppSpacing.lg),
              SicButton(
                label: 'Enregistrer',
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
    await ref.read(simNotifierProvider.notifier).addSim(
          operatorCode: _selectedOperatorCode,
          phoneNumber: _phoneController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    final state = ref.read(simNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString())),
      );
      return;
    }

    Navigator.of(context).pop();
  }
}
