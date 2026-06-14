import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_header.dart';
import '../widgets/pin_keypad.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _otpLength = 6;
  static const _resendSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  // Phase 2 (OTP)
  bool _otpPhase = false;
  String _otp = '';
  bool _otpError = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _username.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim();

  // --- Phase 1 : formulaire -> envoi OTP --------------------------------

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();

    final error = await ref.read(authControllerProvider.notifier).sendOtp(
          _emailValue,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
      if (error == null) {
        _otpPhase = true;
        _otp = '';
        _otpError = false;
      }
    });
    if (error == null) _startResendTimer();
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

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    final error =
        await ref.read(authControllerProvider.notifier).sendOtp(_emailValue);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _otp = '';
      _otpError = false;
      _error = null;
    });
    _startResendTimer();
  }

  // --- Phase 2 : OTP -> inscription -------------------------------------

  void _onDigit(String d) {
    if (_submitting || _otp.length >= _otpLength) return;
    setState(() {
      _otpError = false;
      _error = null;
      _otp += d;
    });
    if (_otp.length == _otpLength) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) _register();
      });
    }
  }

  void _onBackspace() {
    if (_submitting || _otp.isEmpty) return;
    setState(() {
      _otpError = false;
      _otp = _otp.substring(0, _otp.length - 1);
    });
  }

  Future<void> _register() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(authControllerProvider.notifier).register(
          username: _username.text.trim(),
          email: _emailValue,
          password: _password.text,
          passwordConfirm: _passwordConfirm.text,
          phoneNumber: Validators.normalizePhone(_phone.text.trim()),
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          otp: _otp,
        );

    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Inscription reussie. Connectez-vous pour continuer.',
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
      _otpError = true;
      _otp = '';
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _otpPhase
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Creer un compte'),
            ),
      body: _otpPhase ? _buildOtpPhase() : _buildFormPhase(),
    );
  }

  // ----------------------------------------------------------------------

  Widget _buildOtpPhase() {
    final masked = _maskEmail(_emailValue);
    return Column(
      children: [
        PinGradientHeader(
          icon: Icons.mark_email_unread_outlined,
          title: 'Verifiez votre email',
          subtitle: _otpError
              ? (_error ?? 'Code incorrect.')
              : 'Entrez le code a 6 chiffres envoye a\n$masked',
          subtitleError: _otpError,
          showBack: true,
          onBack: _submitting
              ? null
              : () => setState(() {
                    _otpPhase = false;
                    _error = null;
                  }),
          child: PinDots(
            count: _otp.length,
            max: _otpLength,
            error: _otpError,
            onLight: true,
          ),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  Expanded(
                    child: PinKeypad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      enabled: !_submitting,
                    ),
                  ),
                  TextButton(
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
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormPhase() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rejoignez SIC', style: AppTextStyles.displayLarge),
              const SizedBox(height: 4),
              Text(
                'Renseignez vos informations d\'agent.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),

              _label('Identifiant'),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'nom_utilisateur'),
                validator: _validateUsername,
              ),
              const SizedBox(height: AppSpacing.md),

              _label('Email'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'agent@exemple.com'),
                validator: _validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Prenom'),
                        TextFormField(
                          controller: _firstName,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: 'Moussa'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Nom'),
                        TextFormField(
                          controller: _lastName,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: 'Kone'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _label('Numero de telephone'),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  hintText: '70123456',
                  helperText: 'Ce numero deviendra votre premiere SIM.',
                ),
                validator: Validators.validateAnyPhone,
              ),
              const SizedBox(height: AppSpacing.md),

              _label('Mot de passe'),
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
                validator: _validatePassword,
              ),
              const SizedBox(height: AppSpacing.md),

              _label('Confirmer le mot de passe'),
              TextFormField(
                controller: _passwordConfirm,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _continue(),
                decoration: const InputDecoration(hintText: '••••••••'),
                validator: (v) => (v != _password.text)
                    ? 'Les mots de passe ne correspondent pas.'
                    : null,
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.xl),

              SicButton(
                label: 'Continuer',
                isLoading: _submitting,
                onPressed: _continue,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'J\'ai deja un compte — Se connecter',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTextStyles.microLabel),
      );

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final name = email.substring(0, at);
    final domain = email.substring(at);
    final visible = name.length <= 2 ? name : name.substring(0, 2);
    return '$visible${'•' * (name.length - visible.length)}$domain';
  }

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 3) return 'Au moins 3 caracteres.';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) {
      return 'Lettres et chiffres uniquement.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email requis.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Email invalide.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Au moins 8 caracteres.';
    return null;
  }
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
