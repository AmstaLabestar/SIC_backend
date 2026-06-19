import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/providers/biometric_provider.dart';
import '../widgets/account_tile.dart';

/// Ecran "Securite" : code PIN et connexion biometrique, regroupes en un seul
/// endroit (atteint via Mon compte > Securite, en `push` avec retour).
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Securite'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('Code PIN', style: AppTextStyles.microLabel),
            const SizedBox(height: AppSpacing.sm),
            AccountTile(
              icon: Icons.pin_outlined,
              title: 'Modifier le code PIN',
              subtitle: 'Choisir un nouveau code a 4 chiffres',
              onTap: () => context.push('/securite/changer-pin'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Connexion', style: AppTextStyles.microLabel),
            const SizedBox(height: AppSpacing.sm),
            const _BiometricTile(),
          ],
        ),
      ),
    );
  }
}

/// Tuile d'activation de la connexion biometrique (palier P1/P2).
/// Gere son propre etat : disponibilite materielle + activation.
class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool? _available;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = ref.read(biometricRepositoryProvider);
    final available = await bio.isAvailable();
    final enabled = available && await bio.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final bio = ref.read(biometricRepositoryProvider);
    String? error;
    if (value) {
      final result = await bio.enable();
      error = result.fold((f) => f.message, (_) => null);
    } else {
      await bio.disable();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _enabled = value;
    });
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    final subtitle = available == null
        ? 'Verification...'
        : !available
            ? 'Indisponible sur cet appareil'
            : _enabled
                ? 'Activee — empreinte pour connexion et deverrouillage'
                : 'Connexion et deverrouillage par empreinte';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fingerprint_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connexion biometrique',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _enabled,
              onChanged: (available ?? false) ? _toggle : null,
            ),
        ],
      ),
    );
  }
}
