import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../sim_management/presentation/providers/sim_provider.dart';
import '../../../sim_management/presentation/widgets/operator_selector.dart';
import '../../domain/entities/balance_summary.dart';
import '../providers/dashboard_provider.dart';

/// Fiche d'edition d'une SIM : operateur, statut Mobile Money, numero, puis
/// mise a jour ou suppression.
class ModifySimSheet extends ConsumerStatefulWidget {
  const ModifySimSheet({super.key, required this.balance});

  final BalanceSummary balance;

  static Future<void> show(BuildContext context, BalanceSummary balance) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ModifySimSheet(balance: balance),
    );
  }

  @override
  ConsumerState<ModifySimSheet> createState() => _ModifySimSheetState();
}

class _ModifySimSheetState extends ConsumerState<ModifySimSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late String _operatorCode;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.balance.phoneNumber);
    // Fallback si l'operateur de la SIM n'est pas dans la liste connue.
    final operators = ref.read(availableOperatorsProvider);
    _operatorCode = operators.containsKey(widget.balance.operatorCode)
        ? widget.balance.operatorCode
        : (operators.keys.isNotEmpty
            ? operators.keys.first
            : widget.balance.operatorCode);
    _isActive = widget.balance.isActive;
  }

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
              Text('Modifier la SIM', style: AppTextStyles.titleLarge),
              const SizedBox(height: 2),
              Text(
                'Numero actuel : ${widget.balance.maskedPhone}',
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

              _ActiveToggle(
                value: _isActive,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _isActive = v);
                },
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
                decoration: const InputDecoration(hintText: '0701234567'),
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: AppSpacing.xl),

              SicButton(label: 'Mettre a jour la SIM', onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('Supprimer la carte SIM'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final operators = ref.read(availableOperatorsProvider);
    ref.read(dashboardNotifierProvider.notifier).updateSim(
          originalOperatorCode: widget.balance.operatorCode,
          operatorCode: _operatorCode,
          operatorName: operators[_operatorCode] ?? _operatorCode,
          phoneNumber: _phoneController.text.trim(),
          isActive: _isActive,
        );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('SIM mise a jour.'),
        ),
      );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la carte SIM'),
        content: Text(
          'Voulez-vous vraiment supprimer la SIM ${widget.balance.operatorName} ? '
          'Cette action est irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ref
        .read(dashboardNotifierProvider.notifier)
        .removeSim(widget.balance.operatorCode);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('SIM supprimee.'),
        ),
      );
  }
}

class _ActiveToggle extends StatelessWidget {
  const _ActiveToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: value ? AppColors.success : AppColors.textTertiary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Money',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value ? 'Actif sur cette SIM' : 'Desactive',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
