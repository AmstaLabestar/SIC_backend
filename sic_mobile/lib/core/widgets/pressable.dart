import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Micro-interaction reutilisable : l'enfant se reduit legerement au tap puis
/// revient (1 -> 0.97 -> 1), avec retour haptique optionnel.
///
/// Animation implicite courte (<= 300ms) conforme au design system.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 120),
    this.haptic = HapticType.selection,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final HapticType haptic;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

enum HapticType { none, selection, light, medium }

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case HapticType.none:
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
      case HapticType.light:
        HapticFeedback.lightImpact();
      case HapticType.medium:
        HapticFeedback.mediumImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _handleTap : null,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
