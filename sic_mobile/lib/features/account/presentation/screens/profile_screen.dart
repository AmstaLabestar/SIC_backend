import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

/// Ecran "Profil" en lecture seule : informations du compte (identite, contact,
/// statut KYC). L'edition n'est pas exposee (pas d'endpoint backend) : on oriente
/// vers le support.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _kycLabels = {0: 'Starter', 1: 'Verifie', 2: 'Complet'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isAgent = user?.isAgent ?? false;
    final summary = isAgent
        ? ref.watch(dashboardNotifierProvider).valueOrNull
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Section(
              title: 'Identite',
              rows: [
                _Row('Nom complet', user?.fullName ?? '—'),
                _Row('Type de compte', isAgent ? 'Agent (PDV)' : 'Client'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Contact',
              rows: [
                _Row('Telephone', user?.phoneNumber ?? '—'),
                _Row('Email', user?.email ?? '—'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Compte',
              rows: [
                if (isAgent)
                  _Row('Code marchand', summary?.agentCode ?? '—'),
                _Row(
                  'Palier KYC',
                  user == null
                      ? '—'
                      : 'Palier ${user.kycTier} — ${_kycLabels[user.kycTier] ?? ''}',
                ),
                _Row('Statut KYC', _kycStatusLabel(user?.kycStatus)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pour modifier ces informations, contactez le support SIC.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kycStatusLabel(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'APPROVED':
        return 'Verifie';
      case 'SUBMITTED':
        return 'En cours de verification';
      case 'REJECTED':
        return 'Refuse';
      default:
        return 'Non verifie';
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.microLabel),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.caption),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
