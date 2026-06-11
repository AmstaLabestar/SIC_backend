import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

class SicLoading extends StatelessWidget {
  const SicLoading({super.key, this.message = 'Chargement...'});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }
}
