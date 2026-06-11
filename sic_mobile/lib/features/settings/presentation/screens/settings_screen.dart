import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Parametres', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          const _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profil agent',
            subtitle: 'Informations et code agent',
          ),
          const SizedBox(height: AppSpacing.md),
          const _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Confidentialite des soldes',
            subtitle: 'Options de masquage et securite',
          ),
          const SizedBox(height: AppSpacing.md),
          const _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Securite',
            subtitle: 'Biometrie et session',
          ),
          const SizedBox(height: AppSpacing.md),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'A propos de SIC',
            subtitle: 'Version et informations app',
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
        ],
      ),
    );
  }
}
