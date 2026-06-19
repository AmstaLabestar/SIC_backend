import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/account_tile.dart';

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
          AccountTile(
            icon: Icons.badge_outlined,
            title: 'Verification d\'identite',
            subtitle: kycSubtitle,
            onTap: () => context.push('/kyc'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AccountTile(
            icon: Icons.lock_outline_rounded,
            title: 'Securite',
            subtitle: 'Code PIN et biometrie',
            onTap: () => context.push('/securite'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AccountTile(
            icon: Icons.settings_outlined,
            title: 'Parametres',
            subtitle: 'Preferences de l\'application',
            onTap: () => context.push('/dashboard/settings'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AccountTile(
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

