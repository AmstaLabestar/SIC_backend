import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_header.dart';
import '../widgets/pin_keypad.dart';

enum _Phase { enterPin, confirmPin, password }

/// Ecran obligatoire de creation du code PIN (apres login si `has_pin=false`).
///
/// Trois etapes : saisie du PIN (4-6 chiffres), confirmation, puis mot de passe
/// du compte (exige par le backend pour securiser l'operation).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  /// PIN a longueur fixe (standard mobile money). Le backend accepte 4 a 6.
  static const _pinLength = 4;

  _Phase _phase = _Phase.enterPin;
  String _pin = '';
  String _confirm = '';
  bool _mismatch = false;

  final _password = TextEditingController();
  final _passwordKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String get _current => _phase == _Phase.confirmPin ? _confirm : _pin;

  void _onDigit(String d) {
    if (_current.length >= _pinLength) return;
    setState(() {
      _mismatch = false;
      if (_phase == _Phase.confirmPin) {
        _confirm += d;
      } else {
        _pin += d;
      }
    });
    // Auto-validation des que les 4 chiffres sont saisis (laisse la 4e
    // pastille s'afficher avant d'enchainer).
    if (_current.length == _pinLength) {
      final wasConfirm = _phase == _Phase.confirmPin;
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        if (wasConfirm) {
          _validateConfirm();
        } else {
          _goToConfirm();
        }
      });
    }
  }

  void _onBackspace() {
    if (_current.isEmpty) return;
    setState(() {
      _mismatch = false;
      if (_phase == _Phase.confirmPin) {
        _confirm = _confirm.substring(0, _confirm.length - 1);
      } else {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _goToConfirm() {
    setState(() {
      _phase = _Phase.confirmPin;
      _confirm = '';
      _mismatch = false;
    });
  }

  void _validateConfirm() {
    if (_confirm != _pin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _mismatch = true;
        _confirm = '';
      });
      return;
    }
    setState(() => _phase = _Phase.password);
  }

  Future<void> _submitPassword() async {
    FocusScope.of(context).unfocus();
    if (!_passwordKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();

    final error = await ref.read(authControllerProvider.notifier).setupPin(
          password: _password.text,
          pin: _pin,
          pinConfirm: _confirm,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
    // Succes : le claim hasPin passe a true -> la garde de route redirige
    // automatiquement vers /dashboard.
  }

  void _onBack() {
    switch (_phase) {
      case _Phase.enterPin:
        break; // etape initiale obligatoire : pas de sortie.
      case _Phase.confirmPin:
        setState(() {
          _phase = _Phase.enterPin;
          _confirm = '';
          _mismatch = false;
        });
      case _Phase.password:
        setState(() {
          _phase = _Phase.confirmPin;
          _error = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _phase != _Phase.enterPin;
    return PopScope(
      // Ecran obligatoire : on bloque la sortie ; le retour ne fait que revenir
      // a l'etape precedente.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoBack) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: _phase == _Phase.password ? _passwordStep() : _pinStep(canGoBack),
      ),
    );
  }

  // --- Etapes PIN (saisie / confirmation) ---
  Widget _pinStep(bool canGoBack) {
    final isConfirm = _phase == _Phase.confirmPin;
    return Column(
      children: [
        PinGradientHeader(
          showBack: canGoBack,
          onBack: _onBack,
          icon: isConfirm ? Icons.lock_outline_rounded : Icons.pin_outlined,
          title: isConfirm ? 'Confirmez votre code' : 'Creez votre code PIN',
          subtitle: _mismatch
              ? 'Les codes ne correspondent pas. Reessayez.'
              : isConfirm
                  ? 'Saisissez a nouveau votre code a 4 chiffres.'
                  : 'Choisissez un code a 4 chiffres pour proteger\nvotre compte et valider vos operations.',
          subtitleError: _mismatch,
          child: PinDots(
            count: _current.length,
            max: _pinLength,
            error: _mismatch,
            onLight: true,
          ),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            ),
          ),
        ),
      ],
    );
  }

  // --- Etape mot de passe ---
  Widget _passwordStep() {
    return Column(
      children: [
        PinGradientHeader(
          showBack: true,
          onBack: _onBack,
          icon: Icons.verified_user_outlined,
          title: 'Derniere etape',
          subtitle: 'Confirmez avec le mot de passe de\nvotre compte pour activer le code.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, AppSpacing.xl, 24, 24),
            child: Form(
              key: _passwordKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mot de passe', style: AppTextStyles.microLabel),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitPassword(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Mot de passe requis.' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    PinErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SicButton(
                    label: 'Activer mon code PIN',
                    isLoading: _submitting,
                    onPressed: _submitPassword,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
