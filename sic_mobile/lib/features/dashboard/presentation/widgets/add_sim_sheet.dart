import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/operators.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/operator_selector.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/dashboard_provider.dart';

/// Fiche d'ajout d'une SIM : operateur + numero, puis creation cote backend
/// (`POST /puces/`). Le backend refuse les doublons et impose un maximum.
class AddSimSheet extends ConsumerStatefulWidget {
  const AddSimSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddSimSheet(),
    );
  }

  @override
  ConsumerState<AddSimSheet> createState() => _AddSimSheetState();
}

class _AddSimSheetState extends ConsumerState<AddSimSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  late String _operatorCode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    const operators = kAvailableOperators;
    _operatorCode = operators.keys.isNotEmpty ? operators.keys.first : 'OM';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const operators = kAvailableOperators;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text('Ajouter une SIM', style: AppTextStyles.titleLarge),
              const SizedBox(height: 2),
              Text(
                'Selectionnez l\'operateur et saisissez le numero.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Operateur', style: AppTextStyles.microLabel),
              const SizedBox(height: AppSpacing.sm),
              OperatorSelector(
                operators: operators,
                selectedOperatorCode: _operatorCode,
                onSelected: (code) => setState(() => _operatorCode = code),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Numero de telephone', style: AppTextStyles.microLabel),
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
                label: 'Ajouter la SIM',
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

    setState(() => _isSubmitting = true);
    final error = await ref.read(dashboardNotifierProvider.notifier).addSim(
          operatorCode: _operatorCode,
          phoneNumber: _phoneController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('SIM ajoutee.'),
      ),
    );
  }
}
