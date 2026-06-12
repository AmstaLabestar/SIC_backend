import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/pin_keypad.dart';

/// Feuille modale de confirmation par code PIN, exigee AVANT chaque operation
/// (depot / retrait / transfert) — regle metier mobile money : aucune
/// operation sans le code PIN.
///
/// [show] renvoie le `pin_token` temporaire (~5 min) a transmettre a
/// l'operation, ou `null` si l'agent annule (operation a abandonner).
class PinPromptSheet extends ConsumerStatefulWidget {
  const PinPromptSheet({super.key, required this.actionLabel});

  /// Libelle de l'action confirmee (ex: « le depot », « le transfert »),
  /// insere dans le sous-titre.
  final String actionLabel;

  /// Affiche la feuille PIN. Retourne le `pin_token` si verifie, sinon `null`.
  static Future<String?> show(
    BuildContext context, {
    required String actionLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinPromptSheet(actionLabel: actionLabel),
    );
  }

  @override
  ConsumerState<PinPromptSheet> createState() => _PinPromptSheetState();
}

class _PinPromptSheetState extends ConsumerState<PinPromptSheet> {
  static const _pinLength = 4;

  String _pin = '';
  bool _error = false;
  bool _verifying = false;
  String? _message;

  void _onDigit(String d) {
    if (_verifying || _pin.length >= _pinLength) return;
    setState(() {
      _error = false;
      _message = null;
      _pin += d;
    });
    if (_pin.length == _pinLength) {
      // Laisse la 4e pastille s'afficher avant la verification.
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) _verify();
      });
    }
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _error = false;
      _message = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final result =
        await ref.read(authControllerProvider.notifier).verifyPin(_pin);
    if (!mounted) return;
    if (result.error == null) {
      Navigator.of(context).pop(result.token);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _verifying = false;
      _error = true;
      _message = result.error;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Confirmer avec votre PIN',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error
                      ? (_message ?? 'Code PIN incorrect.')
                      : 'Saisissez votre code pour valider ${widget.actionLabel}.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                        _error ? AppColors.danger : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                PinDots(count: _pin.length, max: _pinLength, error: _error),
                const SizedBox(height: AppSpacing.lg),
                PinKeypad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_verifying,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed:
                      _verifying ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Annuler',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
