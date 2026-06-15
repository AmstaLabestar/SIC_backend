import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../domain/entities/operation_result.dart';

/// Feuille de confirmation affichee apres une operation reussie.
class OperationSuccessSheet extends StatelessWidget {
  const OperationSuccessSheet({
    super.key,
    required this.title,
    required this.result,
  });

  final String title;
  final OperationResult result;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required OperationResult result,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OperationSuccessSheet(title: title, result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = result.status.toUpperCase() == 'PENDING';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            FcfaFormatter.format(result.amount),
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _row('Statut', pending ? 'En attente de confirmation' : result.status),
          if (result.commissionSic != null)
            _row('Commission SIC', FcfaFormatter.format(result.commissionSic!)),
          _row('Reference', _shortId(result.transactionId)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Termine'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) =>
      id.length <= 8 ? id : '${id.substring(0, 8)}…';
}
