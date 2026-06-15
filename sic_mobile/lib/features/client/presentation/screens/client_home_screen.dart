import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/widgets/operations_bar.dart';

/// Accueil du compte CLIENT (lot D1-2).
///
/// Modele overlay : le client ne stocke pas de fonds chez SIC (pas de puce ni
/// de float). Il envoie / recoit de l'argent entre reseaux ; le paiement reel
/// passe par CinetPay (branche au lot D0). On affiche donc une carte de
/// bienvenue (sans solde), les actions principales et une relance KYC.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final firstName =
        (user?.firstName.trim().isNotEmpty ?? false) ? user!.firstName : null;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            firstName == null ? 'Bonjour' : 'Bonjour, $firstName',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Votre compte client SIC',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _WelcomeCard(phoneNumber: user?.phoneNumber ?? '—')
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.08, end: 0),
          const SizedBox(height: AppSpacing.lg),

          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Operations', style: AppTextStyles.microLabel),
          ),
          OperationsBar(
            operations: [
              Operation(
                icon: Icons.send_rounded,
                label: 'Envoyer',
                color: AppColors.primary,
                onTap: () => context.push('/operations/envoyer'),
              ),
              Operation(
                icon: Icons.add_card_rounded,
                label: 'Recharger',
                color: AppColors.secondary,
                onTap: () => _comingSoon(context, 'La recharge'),
              ),
              Operation(
                icon: Icons.receipt_long_rounded,
                label: 'Historique',
                color: const Color(0xFF534AB7),
                onTap: () => context.go('/transactions'),
              ),
            ],
          ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          const SizedBox(height: AppSpacing.lg),

          if (user != null && !user.isApproved)
            _KycNudge(
              submitted: user.kycSubmitted,
              onTap: () => context.go('/kyc'),
            ),
        ],
      ),
    );
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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.phoneNumber});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppGradients.hero,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.onPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Compte SIC',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            phoneNumber,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Envoyez et recevez de l\'argent entre tous les reseaux.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _KycNudge extends StatelessWidget {
  const _KycNudge({required this.submitted, required this.onTap});

  final bool submitted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification d\'identite',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    submitted
                        ? 'Dossier en cours de verification'
                        : 'Augmentez vos plafonds de transfert',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
