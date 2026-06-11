import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/sic_error_widget.dart';
import '../../../../core/widgets/sic_loading.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_config_tile.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertNotifierProvider);

    return SafeArea(
      child: state.when(
        loading: () => const SicLoading(),
        error: (error, _) => SicErrorWidget(
          error: error,
          onRetry: () => ref.read(alertNotifierProvider.notifier).refresh(),
        ),
        data: (configs) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          itemCount: configs.length + 2,
          separatorBuilder: (context, index) {
            return const SizedBox(height: AppSpacing.md);
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'Alertes solde',
                style: AppTextStyles.titleLarge,
              );
            }

            if (index == 1) {
              return Text(
                'Configurez les seuils pour etre prevenu avant qu une puce ne bloque une operation.',
                style: AppTextStyles.bodyMedium,
              );
            }

            return AlertConfigTile(config: configs[index - 2]);
          },
        ),
      ),
    );
  }
}
