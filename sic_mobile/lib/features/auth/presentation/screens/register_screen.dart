import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radii.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../../core/widgets/sic_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_hero_scaffold.dart';
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
  final _merchantCode = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  // Type de compte choisi a l'inscription (lot D1). Defaut AGENT.
  bool _isAgent = true;
  bool _submitting = false;
  String? _error;

  // Phase 2 (OTP)
  bool _otpPhase = false;
  String _otp = '';
  bool _otpError = false;
  String? _devCode; // code expose par le backend en DEBUG (helper dev)
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
    _merchantCode.dispose();
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

    final result = await ref.read(authControllerProvider.notifier).sendOtp(
          _emailValue,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = result.error;
      if (result.error == null) {
        _otpPhase = true;
        _otp = '';
        _otpError = false;
        _devCode = result.devCode;
      }
    });
    if (result.error == null) _startResendTimer();
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
    final result =
        await ref.read(authControllerProvider.notifier).sendOtp(_emailValue);
    if (!mounted) return;
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    setState(() {
      _otp = '';
      _otpError = false;
      _error = null;
      _devCode = result.devCode;
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
          accountType: _isAgent ? 'AGENT' : 'CLIENT',
          merchantCode: _isAgent ? _merchantCode.text.trim() : '',
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
    if (_otpPhase) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildOtpPhase(),
      );
    }
    return _buildFormPhase();
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
        if (kDebugMode && _devCode != null) _buildDevBanner(),
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
    return AuthHeroScaffold(
      title: 'Rejoignez SIC',
      showBack: true,
      onBack: _submitting ? null : () => context.go('/login'),
      // Le sous-titre s'adapte au role choisi, en douceur.
      subtitle: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(
          _isAgent
              ? 'Compte agent : gerez vos SIM, le float et la compensation.'
              : 'Compte client : envoyez et recevez de l\'argent simplement.',
          key: ValueKey(_isAgent),
          textAlign: TextAlign.center,
        ),
      ),
      child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Type de compte'),
                    _RoleSelector(
                      isAgent: _isAgent,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _isAgent = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              FadeSlideIn(
                delay: const Duration(milliseconds: 130),
                child: SicTextField(
                  label: 'Identifiant',
                  controller: _username,
                  icon: Icons.alternate_email_rounded,
                  hint: 'nom_utilisateur',
                  textInputAction: TextInputAction.next,
                  validator: _validateUsername,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: SicTextField(
                  label: 'Email',
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  hint: 'agent@exemple.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SicTextField(
                        label: 'Prenom',
                        controller: _firstName,
                        hint: 'Moussa',
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SicTextField(
                        label: 'Nom',
                        controller: _lastName,
                        hint: 'Kone',
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              FadeSlideIn(
                delay: const Duration(milliseconds: 260),
                child: SicTextField(
                  label: 'Numero de telephone',
                  controller: _phone,
                  icon: Icons.phone_iphone_rounded,
                  hint: '70123456',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  helperText: _isAgent
                      ? 'Ce numero deviendra votre premiere SIM.'
                      : 'Numero utilise pour vos transferts.',
                  validator: Validators.validateAnyPhone,
                ),
              ),

              // Le champ code marchand apparait/disparait en douceur selon le
              // role (visible pour un agent uniquement).
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _isAgent
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: SicTextField(
                          label: 'Code marchand',
                          controller: _merchantCode,
                          icon: Icons.store_rounded,
                          hint: '8170275',
                          textInputAction: TextInputAction.next,
                          helperText:
                              'Votre numero de caisse operateur (valide ensuite par SIC).',
                          validator: (v) {
                            if (!_isAgent) return null;
                            if ((v ?? '').trim().isEmpty) {
                              return 'Code marchand requis pour un agent.';
                            }
                            return null;
                          },
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: AppSpacing.md),

              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SicTextField(
                      label: 'Mot de passe',
                      controller: _password,
                      icon: Icons.lock_outline_rounded,
                      hint: '••••••••',
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      validator: _validatePassword,
                    ),
                    _PasswordStrengthBar(listenable: _password),
                    const SizedBox(height: AppSpacing.md),
                    SicTextField(
                      label: 'Confirmer le mot de passe',
                      controller: _passwordConfirm,
                      icon: Icons.lock_outline_rounded,
                      hint: '••••••••',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _continue(),
                      validator: (v) => (v != _password.text)
                          ? 'Les mots de passe ne correspondent pas.'
                          : null,
                    ),
                  ],
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
                delay: const Duration(milliseconds: 340),
                child: Column(
                  children: [
                    SicButton(
                      label: 'Continuer',
                      isLoading: _submitting,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text.rich(
                        TextSpan(
                          text: 'J\'ai deja un compte ?  ',
                          style: AppTextStyles.caption,
                          children: [
                            TextSpan(
                              text: 'Se connecter',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTextStyles.microLabel),
      );

  /// Bannière de confort dev (DEBUG uniquement) : affiche le code OTP renvoyé
  /// par le backend et le pré-remplit au toucher. Jamais compilée en release.
  Widget _buildDevBanner() {
    final code = _devCode!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitting
              ? null
              : () {
                  setState(() {
                    _otpError = false;
                    _otp = code;
                  });
                  _register();
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bug_report_outlined,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'DEV · code $code — toucher pour remplir',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

/// Selecteur segmente Agent / Client (lot D1) avec un pouce qui glisse sous
/// l'option active (AnimatedAlign) pour une transition fluide et premium.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.isAgent, required this.onChanged});

  final bool isAgent;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbWidth = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              // Pouce coulissant derriere les libelles.
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment:
                    isAgent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: thumbWidth,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _option(
                    label: 'Agent',
                    icon: Icons.store_rounded,
                    selected: isAgent,
                    onTap: onChanged == null ? null : () => onChanged!(true),
                  ),
                  _option(
                    label: 'Client',
                    icon: Icons.person_rounded,
                    selected: !isAgent,
                    onTap: onChanged == null ? null : () => onChanged!(false),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _option({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.0 : 0.92,
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.bodyMedium.copyWith(
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicateur de force du mot de passe : 4 segments qui se remplissent au fur
/// et a mesure de la saisie, avec une couleur qui passe du rouge au vert. Se
/// reconstruit en ecoutant le controleur du champ.
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.listenable});

  final TextEditingController listenable;

  /// Score 0..4 selon longueur et variete de caracteres.
  int _score(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 8) score++;
    if (v.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      score++;
    }
    return score.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final value = listenable.text;
        if (value.isEmpty) {
          return const SizedBox(height: AppSpacing.sm);
        }
        final score = _score(value);
        const labels = ['Faible', 'Faible', 'Moyen', 'Bon', 'Excellent'];
        final colors = [
          AppColors.danger,
          AppColors.danger,
          AppColors.warning,
          AppColors.success,
          AppColors.success,
        ];
        final color = colors[score];
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score
                          ? color
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
              const SizedBox(width: AppSpacing.sm),
              Text(
                labels[score],
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
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
