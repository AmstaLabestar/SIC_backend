import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/fcfa_formatter.dart';

enum SicAmountSize { large, medium, small }

class SicAmountDisplay extends StatelessWidget {
  const SicAmountDisplay({
    super.key,
    required this.amount,
    this.color,
    this.size = SicAmountSize.medium,
  });

  final double amount;
  final Color? color;
  final SicAmountSize size;

  @override
  Widget build(BuildContext context) {
    final style = switch (size) {
      SicAmountSize.large => AppTextStyles.amount.copyWith(fontSize: 32),
      SicAmountSize.medium => AppTextStyles.amount,
      SicAmountSize.small => AppTextStyles.amountSmall,
    };

    final formattedAmount = FcfaFormatter.format(amount);

    return Text(
      formattedAmount,
      style: style.copyWith(color: color ?? AppColors.accent),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: formattedAmount,
    );
  }
}
