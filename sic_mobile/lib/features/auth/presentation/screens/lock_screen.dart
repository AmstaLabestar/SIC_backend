import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/app_lock_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_header.dart';
import '../widgets/pin_keypad.dart';

/// Ecran de verrouillage : l'agent saisit son code PIN pour deverrouiller
/// l'app (ouverture a froid ou retour d'arriere-plan apres inactivite).
///
/// Le PIN est verifie cote backend (`/auth/pin/verify/`). En cas de succes,
/// l'app se deverrouille et la garde de route redirige vers le tableau de bord.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
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
      // Succes : la garde de route redirige automatiquement vers /dashboard.
      ref.read(appLockProvider.notifier).unlock();
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

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final greeting = (user != null && user.firstName.trim().isNotEmpty)
        ? 'Bonjour ${user.firstName}, saisissez votre code\npour deverrouiller l\'application.'
        : 'Saisissez votre code a 4 chiffres\npour deverrouiller l\'application.';

    return PopScope(
      // Ecran de verrouillage : pas de retour possible (seul le PIN ou la
      // deconnexion en sortent).
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            PinGradientHeader(
              icon: Icons.lock_outline_rounded,
              title: 'Application verrouillee',
              subtitle: _error
                  ? (_message ?? 'Code PIN incorrect.')
                  : greeting,
              subtitleError: _error,
              child: PinDots(
                count: _pin.length,
                max: _pinLength,
                error: _error,
                onLight: true,
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      Expanded(
                        child: PinKeypad(
                          onDigit: _onDigit,
                          onBackspace: _onBackspace,
                          enabled: !_verifying,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _verifying ? null : _logout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          'Ce n\'est pas vous ? Se deconnecter',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
