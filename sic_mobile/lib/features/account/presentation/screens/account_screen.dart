import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/biometric_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Ecran "Mon compte" : profil de l'agent + acces parametres / securite /
/// deconnexion.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isClient = user?.isClient ?? false;
    // Un CLIENT n'a pas de profil agent (puces/float) : on s'appuie sur AuthUser
    // et on masque le code agent + le badge "Verifie" agent (lot D1-2).
    final summary = isClient
        ? null
        : ref.watch(dashboardNotifierProvider).valueOrNull;
    final name = user?.fullName ?? summary?.agentName ?? 'Compte SIC';
    final code = isClient ? '' : (summary?.agentCode ?? '—');
    final initials = summary?.agentInitials ?? _initialsFrom(name);
    final tier = user?.kycTier ?? 0;
    final kycSubtitle = user != null && user.kycSubmitted
        ? 'Dossier en cours de verification'
        : tier >= 2
            ? 'Palier 2 — Complet'
            : 'Palier $tier — augmenter vos plafonds';

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Mon compte', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _ProfileHeader(
            name: name,
            code: code,
            initials: initials,
            showVerified: !isClient,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Tile(
            icon: Icons.badge_outlined,
            title: 'Verification d\'identite',
            subtitle: kycSubtitle,
            onTap: () => context.go('/kyc'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Tile(
            icon: Icons.settings_outlined,
            title: 'Parametres',
            subtitle: 'Preferences de l\'application',
            onTap: () => context.go('/dashboard/settings'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _BiometricTile(),
          const SizedBox(height: AppSpacing.sm),
          _Tile(
            icon: Icons.lock_outline_rounded,
            title: 'Securite',
            subtitle: 'Biometrie, code PIN et session',
            onTap: () => _comingSoon(context, 'Securite'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Tile(
            icon: Icons.logout_rounded,
            title: 'Deconnexion',
            subtitle: 'Fermer la session',
            danger: true,
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'SIC Mobile · v1.0.0',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Voulez-vous fermer votre session ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Se deconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // La garde de route renvoie automatiquement vers /login.
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'SIC';
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'SIC' : letters;
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$label — bientot disponible.'),
        ),
      );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.code,
    required this.initials,
    this.showVerified = true,
  });

  final String name;
  final String code;
  final String initials;
  final bool showVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Text(
              initials,
              style: AppTextStyles.avatarInitials.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                showVerified
                    ? Row(
                        children: [
                          Text(code, style: AppTextStyles.caption),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Verifie',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Client',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile d'activation de la connexion biometrique (palier P1/P2).
/// Gere son propre etat : disponibilite materielle + activation.
class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool? _available;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = ref.read(biometricRepositoryProvider);
    final available = await bio.isAvailable();
    final enabled = available && await bio.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final bio = ref.read(biometricRepositoryProvider);
    String? error;
    if (value) {
      final result = await bio.enable();
      error = result.fold((f) => f.message, (_) => null);
    } else {
      await bio.disable();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _enabled = value;
    });
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    final subtitle = available == null
        ? 'Verification...'
        : !available
            ? 'Indisponible sur cet appareil'
            : _enabled
                ? 'Activee — empreinte pour connexion et deverrouillage'
                : 'Connexion et deverrouillage par empreinte';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fingerprint_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connexion biometrique',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _enabled,
              onChanged: (available ?? false) ? _toggle : null,
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
