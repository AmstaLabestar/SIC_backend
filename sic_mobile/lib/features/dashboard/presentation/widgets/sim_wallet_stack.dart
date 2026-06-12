import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/fcfa_formatter.dart';
import '../../domain/entities/balance_summary.dart';
import '../providers/dashboard_provider.dart';

/// Identite stable d'une SIM (cle de widget + etat de visibilite).
/// Deux puces du meme operateur restent distinctes grace a l'id backend
/// (fallback : operateur + numero).
String simIdentity(BalanceSummary b) =>
    b.id ?? '${b.operatorCode}_${b.phoneNumber}';

/// Pile de cartes SIM facon Apple Wallet : une carte depliee en haut, les
/// autres repliees en dessous. Un tap sur une carte repliee la fait remonter.
class SimWalletStack extends ConsumerStatefulWidget {
  const SimWalletStack({
    super.key,
    required this.balances,
    this.onCardTap,
    this.onHistory,
    this.onModify,
  });

  final List<BalanceSummary> balances;
  final ValueChanged<BalanceSummary>? onCardTap;
  final ValueChanged<BalanceSummary>? onHistory;
  final ValueChanged<BalanceSummary>? onModify;

  @override
  ConsumerState<SimWalletStack> createState() => _SimWalletStackState();
}

class _SimWalletStackState extends ConsumerState<SimWalletStack> {
  static const double _expandedH = 142;
  static const double _peek = 46;
  static const double _overlap = 14;

  int _selected = 0;

  void _select(int index) {
    if (_selected == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final balances = widget.balances;
    if (balances.isEmpty) return const SizedBox.shrink();
    if (_selected >= balances.length) _selected = 0;

    if (balances.length == 1) {
      return SizedBox(height: _expandedH, child: _expandedCard(balances.first));
    }

    // Ordre d'affichage : carte selectionnee depliee en haut, puis les autres
    // repliees dans leur ordre d'origine.
    final collapsed = <int>[
      for (var i = 0; i < balances.length; i++)
        if (i != _selected) i,
    ];

    final totalHeight = _expandedH + collapsed.length * _peek;

    final children = <Widget>[];
    // Cartes repliees (rendu du haut vers le bas pour un z-order correct).
    for (var j = 0; j < collapsed.length; j++) {
      final index = collapsed[j];
      children.add(
        AnimatedPositioned(
          key: ValueKey('sim_${simIdentity(balances[index])}'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          top: _expandedH - _overlap + j * _peek,
          height: _peek + _overlap,
          child: _CollapsedCard(
            balance: balances[index],
            onTap: () => _select(index),
          ),
        ),
      );
    }
    // Carte depliee, dessinee en dernier (au-dessus).
    children.add(
      AnimatedPositioned(
        key: ValueKey('sim_${simIdentity(balances[_selected])}'),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        left: 0,
        right: 0,
        top: 0,
        height: _expandedH,
        child: _expandedCard(balances[_selected]),
      ),
    );

    return SizedBox(
      height: totalHeight,
      child: Stack(children: children),
    );
  }

  Widget _expandedCard(BalanceSummary balance) {
    final isVisible = ref.watch(simVisibilityProvider(simIdentity(balance)));
    final gradient = _operatorGradient(balance.operatorCode);
    final status = _statusOf(balance);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onCardTap?.call(balance);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        // Le contenu garde sa hauteur pleine et est clippe pendant l'animation
        // d'expansion (evite le BOTTOM OVERFLOWED transitoire).
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: OverflowBox(
            minHeight: _expandedH,
            maxHeight: _expandedH,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          balance.operatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusChip(status: status),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _amount(balance, isVisible)),
                      _EyeButton(
                        isVisible: isVisible,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(simVisibilityProvider(simIdentity(balance))
                                  .notifier)
                              .update((v) => !v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassButton(
                          icon: Icons.history_rounded,
                          label: 'Historique',
                          onTap: () => widget.onHistory?.call(balance),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _GlassButton(
                          icon: Icons.edit_outlined,
                          label: 'Modifier',
                          solid: true,
                          onTap: () => widget.onModify?.call(balance),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _amount(BalanceSummary balance, bool isVisible) {
    final text = Text(
      FcfaFormatter.format(balance.balance),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.simAmount.copyWith(
        color: AppColors.onPrimary,
        fontSize: 26,
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isVisible
          ? KeyedSubtree(key: const ValueKey('v'), child: text)
          : ClipRect(
              key: const ValueKey('h'),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: text,
              ),
            ),
    );
  }
}

class _CollapsedCard extends StatelessWidget {
  const _CollapsedCard({required this.balance, required this.onTap});

  final BalanceSummary balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = _operatorGradient(balance.operatorCode);
    final status = _statusOf(balance);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                color: status.dotOnGradient,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              balance.operatorName,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              FcfaFormatter.formatCompact(balance.balance),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.isVisible, required this.onTap});

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onPrimary.withValues(alpha: 0.16),
        ),
        child: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off,
          color: AppColors.onPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    this.solid = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.onPrimary.withValues(alpha: solid ? 0.24 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.onPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _SimStatusData status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SimStatusData {
  const _SimStatusData({required this.label, required this.dotOnGradient});

  final String label;
  final Color dotOnGradient;
}

_SimStatusData _statusOf(BalanceSummary balance) {
  if (balance.isEmpty) {
    return const _SimStatusData(label: 'Vide', dotOnGradient: Color(0xFFFFD2D2));
  }
  if (balance.isLow) {
    return const _SimStatusData(label: 'Faible', dotOnGradient: Color(0xFFFFE3B0));
  }
  return const _SimStatusData(label: 'OK', dotOnGradient: Color(0xFFFFFFFF));
}

LinearGradient _operatorGradient(String code) {
  final colors = switch (code.toUpperCase()) {
    'OM' => const [Color(0xFFFF6200), Color(0xFFFF8C42)],
    'MOOV' => const [Color(0xFF0057B8), Color(0xFF2E80D8)],
    'TELECEL' => const [Color(0xFF1B8C5E), Color(0xFF22C97A)],
    'MTN' => const [Color(0xFFE6A700), Color(0xFFFFCC00)],
    'WAVE' => const [Color(0xFF1A73E8), Color(0xFF4BA3F5)],
    'CORIS' => const [Color(0xFF8B1A1A), Color(0xFFBF4040)],
    _ => const [Color(0xFF334155), Color(0xFF64748B)],
  };
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}
