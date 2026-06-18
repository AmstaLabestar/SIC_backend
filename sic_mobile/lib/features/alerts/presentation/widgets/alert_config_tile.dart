import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../../../core/widgets/operator_logo.dart';
import '../../domain/entities/alert_config.dart';
import '../providers/alert_provider.dart';
import 'threshold_slider.dart';

class AlertConfigTile extends ConsumerStatefulWidget {
  const AlertConfigTile({super.key, required this.config});

  final AlertConfig config;

  @override
  ConsumerState<AlertConfigTile> createState() => _AlertConfigTileState();
}

class _AlertConfigTileState extends ConsumerState<AlertConfigTile> {
  late AlertConfig _draftConfig;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _draftConfig = widget.config;
  }

  @override
  void didUpdateWidget(covariant AlertConfigTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _draftConfig = widget.config;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OperatorLogo(operatorCode: _draftConfig.operatorCode),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_draftConfig.operatorName} · ${_draftConfig.phoneNumber}',
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      _draftConfig.isEnabled ? 'Alerte active' : 'Alerte inactive',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _draftConfig.isEnabled,
                activeThumbColor: AppColors.success,
                onChanged: (value) {
                  _updateDraft(_draftConfig.copyWith(isEnabled: value));
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ThresholdSlider(
            value: _draftConfig.threshold,
            isEnabled: _draftConfig.isEnabled,
            onChanged: (value) {
              _updateDraft(_draftConfig.copyWith(threshold: value));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _draftConfig.isEnabled
                ? 'Alerte si solde ${_draftConfig.phoneNumber} < ${FcfaFormatter.format(_draftConfig.threshold)}'
                : 'Aucune alerte ne sera envoyee pour ${_draftConfig.phoneNumber}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _updateDraft(AlertConfig config) {
    setState(() => _draftConfig = config);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(alertNotifierProvider.notifier).save(_draftConfig);
    });
  }
}
