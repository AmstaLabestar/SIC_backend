import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_button.dart';
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
  bool _obscure = true;
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
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                  child: Text(
                    'SIC',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Bienvenue', style: AppTextStyles.displayLarge),
                const SizedBox(height: 4),
                Text(
                  'Connectez-vous a votre espace agent.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Numero de telephone', style: AppTextStyles.microLabel),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _identifierController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(hintText: '70 12 34 56'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Numero de telephone requis'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mot de passe', style: AppTextStyles.microLabel),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
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
                      (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: AppSpacing.xl),
                SicButton(
                  label: 'Se connecter',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                if (_biometricReady) ...[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton.icon(
                      onPressed: _submitting ? null : _loginWithBiometric,
                      icon: const Icon(Icons.fingerprint_rounded, size: 24),
                      label: Text(
                        'Se connecter avec l\'empreinte',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(
                      'Pas encore de compte ? Creer un compte',
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
