import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/sic_button.dart';
import '../../../../core/widgets/sic_error_widget.dart';
import '../../../../core/widgets/sic_loading.dart';
import '../../domain/entities/sim_card.dart';
import '../providers/sim_provider.dart';
import '../widgets/add_sim_bottom_sheet.dart';
import '../widgets/sim_card_tile.dart';

class SimManagementScreen extends ConsumerWidget {
  const SimManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(simNotifierProvider);

    return SafeArea(
      child: state.when(
        loading: () => const SicLoading(),
        error: (error, _) => SicErrorWidget(
          error: error,
          onRetry: () => ref.read(simNotifierProvider.notifier).refresh(),
        ),
        data: (sims) => Column(
          children: [
            _SimHeader(onAddTap: () => AddSimBottomSheet.show(context)),
            Expanded(
              child: sims.isEmpty
                  ? const _EmptySimsState()
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () {
                        return ref.read(simNotifierProvider.notifier).refresh();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        itemCount: sims.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: AppSpacing.md);
                        },
                        itemBuilder: (context, index) {
                          final sim = sims[index];

                          return SimCardTile(
                            sim: sim,
                            onToggle: () => _confirmToggle(context, ref, sim),
                            onEditThreshold: () {
                              _showThresholdSheet(context, ref, sim);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggle(
    BuildContext context,
    WidgetRef ref,
    SimCard sim,
  ) async {
    final shouldToggle = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sim.isActive ? 'Desactiver la puce ?' : 'Activer la puce ?'),
        content: Text(
          sim.isActive
              ? 'Cette puce contient peut-etre du solde disponible. Confirmez uniquement si elle ne doit plus servir aux operations.'
              : 'Cette puce redeviendra disponible pour les operations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(sim.isActive ? 'Desactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (shouldToggle != true) {
      return;
    }

    await ref.read(simNotifierProvider.notifier).toggleSim(
          id: sim.id,
          isActive: !sim.isActive,
        );
  }

  Future<void> _showThresholdSheet(
    BuildContext context,
    WidgetRef ref,
    SimCard sim,
  ) {
    final controller = TextEditingController(
      text: sim.alertThreshold.round().toString(),
    );
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seuil ${sim.operatorName}', style: AppTextStyles.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Seuil alerte',
                    suffixText: 'FCFA',
                  ),
                  validator: Validators.validateAmount,
                ),
                const SizedBox(height: AppSpacing.lg),
                SicButton(
                  label: 'Enregistrer',
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    await ref.read(simNotifierProvider.notifier).updateThreshold(
                          id: sim.id,
                          threshold: double.parse(controller.text),
                        );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }
}

class _SimHeader extends StatelessWidget {
  const _SimHeader({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Mes puces', style: AppTextStyles.titleLarge),
          ),
          IconButton.filled(
            tooltip: 'Ajouter une puce',
            onPressed: onAddTap,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptySimsState extends StatelessWidget {
  const _EmptySimsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sim_card_outlined,
              size: 52,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Aucune puce ajoutee', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez votre premiere puce pour suivre vos soldes.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
