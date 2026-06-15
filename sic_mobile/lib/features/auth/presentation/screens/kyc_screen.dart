import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_button.dart';
import '../providers/auth_provider.dart';

/// Verification d'identite par paliers (lot C3).
///
/// Montee d'un palier a la fois : T0 -> T1 (piece d'identite) -> T2 (selfie).
/// Affiche l'etat courant (en revue / rejete / palier atteint) et le formulaire
/// d'upload des documents requis pour le palier suivant.
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _picker = ImagePicker();
  String? _frontPath;
  String? _backPath;
  String? _selfiePath;
  bool _submitting = false;
  String? _error;

  Future<void> _pick(void Function(String) assign) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file != null) setState(() => assign(file.path));
  }

  Future<void> _submit(int targetTier) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();

    final error = await ref.read(authControllerProvider.notifier).submitKyc(
          requestedTier: targetTier,
          idCardFrontPath: _frontPath,
          idCardBackPath: _backPath,
          selfiePath: _selfiePath,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Dossier envoye. Verification en cours.'),
            duration: Duration(seconds: 4),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final tier = user?.kycTier ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Verification d\'identite'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierBadge(tier: tier),
              const SizedBox(height: AppSpacing.lg),
              if (user != null && user.kycSubmitted)
                _InfoCard(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.primary,
                  title: 'Dossier en cours de verification',
                  message:
                      'Votre demande de palier ${user.kycRequestedTier ?? ''} '
                      'est en cours d\'examen. Vous serez notifie de la decision.',
                )
              else if (tier >= 2)
                const _InfoCard(
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  title: 'Palier maximal atteint',
                  message:
                      'Votre compte est entierement verifie. Vous beneficiez '
                      'des plafonds les plus eleves.',
                )
              else
                _buildForm(context, tier, user?.kycRejected ?? false,
                    user?.kycRejectionReason ?? ''),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, int tier, bool rejected, String reason) {
    final targetTier = tier + 1;
    // Documents requis pour le palier vise.
    final needFront = tier < 1; // recto piece pour atteindre T1
    final needSelfie = targetTier >= 2; // selfie pour atteindre T2

    final ready =
        (!needFront || _frontPath != null) && (!needSelfie || _selfiePath != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rejected && reason.isNotEmpty) ...[
          _InfoCard(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            title: 'Dossier precedent rejete',
            message: '$reason\nVous pouvez soumettre a nouveau ci-dessous.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          targetTier == 1
              ? 'Passer au palier 1 — Verifie'
              : 'Passer au palier 2 — Complet',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          targetTier == 1
              ? 'Ajoutez votre piece d\'identite pour augmenter vos plafonds.'
              : 'Ajoutez un selfie pour finaliser votre verification.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (needFront) ...[
          _DocTile(
            label: 'Piece d\'identite (recto)',
            path: _frontPath,
            onTap: _submitting ? null : () => _pick((p) => _frontPath = p),
          ),
          const SizedBox(height: AppSpacing.md),
          _DocTile(
            label: 'Piece d\'identite (verso) — optionnel',
            path: _backPath,
            onTap: _submitting ? null : () => _pick((p) => _backPath = p),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (needSelfie) ...[
          _DocTile(
            label: 'Selfie',
            path: _selfiePath,
            onTap: _submitting ? null : () => _pick((p) => _selfiePath = p),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _InfoCard(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            title: 'Erreur',
            message: _error!,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        SicButton(
          label: 'Envoyer pour verification',
          isLoading: _submitting,
          onPressed: ready ? () => _submit(targetTier) : null,
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final int tier;

  static const _labels = ['Starter', 'Verifie', 'Complet'];

  @override
  Widget build(BuildContext context) {
    final label = tier >= 0 && tier < _labels.length ? _labels[tier] : 'Starter';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Palier actuel',
              style: AppTextStyles.caption.copyWith(color: AppColors.onPrimary)),
          const SizedBox(height: 4),
          Text('Palier $tier — $label',
              style: AppTextStyles.titleLarge
                  .copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.label, required this.path, required this.onTap});
  final String label;
  final String? path;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picked = path != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: picked
                ? AppColors.success.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            if (picked)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(path!),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.textTertiary),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                picked ? '$label — ajoute' : label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: picked ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(picked ? Icons.check_circle_rounded : Icons.chevron_right,
                color: picked ? AppColors.success : AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(message, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
