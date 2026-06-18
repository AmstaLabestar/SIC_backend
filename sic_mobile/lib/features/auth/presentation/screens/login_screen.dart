import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../../core/widgets/sic_logo.dart';
import '../../../../core/widgets/sic_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/biometric_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  /// Affiche le bouton empreinte si la biometrie est disponible ET activee
  /// (l'agent l'a enrolee depuis son compte).
  Future<void> _initBiometric() async {
    final bio = ref.read(biometricRepositoryProvider);
    final available = await bio.isAvailable();
    final enabled = available && await bio.isEnabled();
    if (mounted && enabled) setState(() => _biometricReady = true);
  }

  Future<void> _loginWithBiometric() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error =
        await ref.read(authControllerProvider.notifier).loginWithBiometric();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();

    // Identifiant = numero de telephone (lot A3). On normalise en minuscules
    // pour le repli username (comptes existants/demo) ; sans effet sur les
    // chiffres d'un numero.
    final identifier = _identifierController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(identifier, password);

    if (!mounted) return;
    setState(() => _submitting = false);

    // Nouvel appareil (lot A4) : aller saisir l'OTP recu par email.
    if (result.deviceEmail != null) {
      context.go('/verify-device', extra: {
        'identifier': identifier,
        'password': password,
        'email': result.deviceEmail,
      });
      return;
    }

    setState(() => _error = result.error);
    // En cas de succes, la garde de route redirige vers /dashboard.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SicLogo(size: 76),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Bienvenue', style: AppTextStyles.displayLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Connectez-vous a votre espace SIC.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: SicTextField(
                    label: 'Numero de telephone',
                    controller: _identifierController,
                    icon: Icons.phone_iphone_rounded,
                    hint: '70 12 34 56',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Numero de telephone requis'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: SicTextField(
                    label: 'Mot de passe',
                    controller: _passwordController,
                    icon: Icons.lock_outline_rounded,
                    hint: '••••••••',
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _ErrorBanner(message: _error!),
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: Column(
                    children: [
                      SicButton(
                        label: 'Se connecter',
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                      if (_biometricReady) ...[
                        const SizedBox(height: AppSpacing.md),
                        _BiometricButton(
                          onPressed:
                              _submitting ? null : _loginWithBiometric,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: Text(
                          'Mot de passe oublie ?',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _SignupPrompt(onTap: () => context.go('/register')),
                    ],
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

/// Bouton biometrie discret mais tactile (surface + bord, retour au tap).
class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.fingerprint_rounded, size: 22),
        label: Text(
          'Se connecter avec l\'empreinte',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Invitation a creer un compte (texte secondaire + accent cliquable).
class _SignupPrompt extends StatelessWidget {
  const _SignupPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text.rich(
        TextSpan(
          text: 'Pas encore de compte ?  ',
          style: AppTextStyles.caption,
          children: [
            TextSpan(
              text: 'Creer un compte',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
