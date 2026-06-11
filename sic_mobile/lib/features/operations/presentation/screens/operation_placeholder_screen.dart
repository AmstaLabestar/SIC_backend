import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Ecran provisoire d'une operation (Phase 3 : moteur de compensation).
class OperationPlaceholderScreen extends StatelessWidget {
  const OperationPlaceholderScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: AppColors.primaryLight,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('$label — bientot disponible', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Cette operation arrive avec la phase Operations.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Retour a l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
