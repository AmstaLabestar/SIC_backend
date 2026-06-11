import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/operator_logo.dart';

class OperatorSelector extends StatelessWidget {
  const OperatorSelector({
    super.key,
    required this.operators,
    required this.selectedOperatorCode,
    required this.onSelected,
  });

  final Map<String, String> operators;
  final String selectedOperatorCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = operators.entries.toList();

    return GridView.builder(
      itemCount: entries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 74,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = entry.key == selectedOperatorCode;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                width: isSelected ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                OperatorLogo(operatorCode: entry.key, size: 34),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    entry.value,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
