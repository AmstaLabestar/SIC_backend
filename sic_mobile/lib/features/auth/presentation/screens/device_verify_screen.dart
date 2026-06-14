import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_header.dart';
import '../widgets/pin_keypad.dart';

/// Verification d'un nouvel appareil (lot A4 - device binding).
///
/// Apres un login refuse pour cause de nouvel appareil, le backend a envoye un
/// OTP par email. L'agent saisit ce code ici ; en cas de succes l'appareil
/// devient de confiance et la session est ouverte (la garde de route redirige).
class DeviceVerifyScreen extends ConsumerStatefulWidget {
  const DeviceVerifyScreen({
    super.key,
    required this.identifier,
    required this.password,
    required this.email,
  });

  /// Identifiant saisi au login (numero de telephone ou username).
  final String identifier;

  /// Mot de passe saisi au login (re-verifie cote backend avec l'OTP).
  final String password;

  /// Email masque vers lequel l'OTP a ete envoye (affichage).
  final String email;

  @override
  ConsumerState<DeviceVerifyScreen> createState() => _DeviceVerifyScreenState();
}

class _DeviceVerifyScreenState extends ConsumerState<DeviceVerifyScreen> {
  static const _otpLength = 6;

  String _otp = '';
  bool _otpError = false;
  bool _submitting = false;
  String? _error;

  void _onDigit(String d) {
    if (_submitting || _otp.length >= _otpLength) return;
    setState(() {
      _otpError = false;
      _error = null;
      _otp += d;
    });
    if (_otp.length == _otpLength) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) _verify();
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

  Future<void> _verify() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(authControllerProvider.notifier).verifyDevice(
          identifier: widget.identifier,
          password: widget.password,
          otp: _otp,
        );

    if (!mounted) return;
    if (error == null) {
      // Succes : la garde de route redirige vers /pin-setup, /lock ou /dashboard.
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
      body: Column(
        children: [
          PinGradientHeader(
            icon: Icons.verified_user_outlined,
            title: 'Nouvel appareil',
            subtitle: _otpError
                ? (_error ?? 'Code incorrect.')
                : 'Pour votre securite, entrez le code a 6 chiffres '
                    'envoye a\n${widget.email}',
            subtitleError: _otpError,
            showBack: true,
            onBack: _submitting ? null : () => context.go('/login'),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        'Ce code protege votre compte contre une connexion '
                        'depuis un appareil inconnu.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
