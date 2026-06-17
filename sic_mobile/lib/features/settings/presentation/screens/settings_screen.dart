import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Parametres', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profil agent',
            subtitle: 'Informations et code agent',
            onTap: () => _comingSoon(context, 'Le profil'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Confidentialite des soldes',
            subtitle: 'Options de masquage et securite',
            onTap: () => _comingSoon(context, 'La confidentialite des soldes'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Securite',
            subtitle: 'Biometrie et session',
            onTap: () => _comingSoon(context, 'Les options de securite'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'A propos de SIC',
            subtitle: 'Version et informations app',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'SIC Mobile',
              applicationVersion: 'v1.0.0',
              applicationLegalese: '© 2026 SIC',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
