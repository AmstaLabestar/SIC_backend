import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/auth_provider.dart';

/// Reinitialisation du mot de passe par OTP email (lot A5).
///
/// Phase 1 : l'agent saisit son identifiant (telephone, email ou username) ;
/// un code est envoye a l'email du compte (reponse neutre cote backend).
/// Phase 2 : il saisit le code recu + un nouveau mot de passe. En cas de
/// succes, le mot de passe est change (et le PIN reinitialise cote serveur).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final _requestKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  bool _otpPhase = false;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _identifier.dispose();
    _otp.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  // --- Phase 1 : demande du code ---------------------------------------

  Future<void> _request() async {
    FocusScope.of(context).unfocus();
    if (!_requestKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();

    final error = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_identifier.text.trim().toLowerCase());

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
      if (error == null) _otpPhase = true;
    });
    if (error == null) _startResendTimer();
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    final error = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_identifier.text.trim().toLowerCase());
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    _startResendTimer();
  }

  // --- Phase 2 : confirmation ------------------------------------------

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    if (!_confirmKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error =
        await ref.read(authControllerProvider.notifier).confirmPasswordReset(
              identifier: _identifier.text.trim().toLowerCase(),
              otp: _otp.text.trim(),
              newPassword: _password.text,
            );

    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Mot de passe reinitialise. Connectez-vous.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      context.go('/login');
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mot de passe oublie'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting
              ? null
              : () {
                  if (_otpPhase) {
                    setState(() {
                      _otpPhase = false;
                      _error = null;
                    });
                  } else {
                    context.go('/login');
                  }
                },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _otpPhase ? _buildConfirmPhase() : _buildRequestPhase(),
        ),
      ),
    );
  }

  Widget _buildRequestPhase() {
    return Form(
      key: _requestKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reinitialiser', style: AppTextStyles.displayLarge),
          const SizedBox(height: 4),
          Text(
            'Entrez votre numero de telephone. Un code sera envoye a l\'email '
            'associe a votre compte.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('Numero de telephone ou email'),
          TextFormField(
            controller: _identifier,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _request(),
            decoration: const InputDecoration(hintText: '70123456'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Identifiant requis' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          SicButton(
            label: 'Envoyer le code',
            isLoading: _submitting,
            onPressed: _request,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPhase() {
    return Form(
      key: _confirmKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau mot de passe', style: AppTextStyles.displayLarge),
          const SizedBox(height: 4),
          Text(
            'Entrez le code recu par email puis choisissez un nouveau mot de '
            'passe.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('Code de verification'),
          TextFormField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: '123456',
              counterText: '',
            ),
            validator: (v) => (v == null || v.trim().length != 6)
                ? 'Code a 6 chiffres requis'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _label('Nouveau mot de passe'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
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
                (v == null || v.length < 8) ? 'Au moins 8 caracteres.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _label('Confirmer le mot de passe'),
          TextFormField(
            controller: _passwordConfirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _confirm(),
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: (v) => (v != _password.text)
                ? 'Les mots de passe ne correspondent pas.'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          SicButton(
            label: 'Reinitialiser',
            isLoading: _submitting,
            onPressed: _confirm,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: (_resendIn > 0 || _submitting) ? null : _resend,
              child: Text(
                _resendIn > 0
                    ? 'Renvoyer le code (${_resendIn}s)'
                    : 'Renvoyer le code',
                style: AppTextStyles.caption.copyWith(
                  color: _resendIn > 0
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTextStyles.microLabel),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
