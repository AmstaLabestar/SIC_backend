import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/fcfa_formatter.dart';

class ThresholdSlider extends StatelessWidget {
  const ThresholdSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.isEnabled = true,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: value.clamp(10000, 300000),
      min: 10000,
      max: 300000,
      divisions: 29,
      activeColor: AppColors.accent,
      inactiveColor: AppColors.cardBorder,
      label: FcfaFormatter.format(value),
      onChanged: isEnabled ? onChanged : null,
    );
  }
}
