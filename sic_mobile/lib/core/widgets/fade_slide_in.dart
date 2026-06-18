import 'package:flutter/material.dart';

/// Animation d'entree douce : l'enfant apparait en fondu et glisse legerement
/// vers le haut. Un [delay] permet d'orchestrer une cascade (stagger) entre
/// plusieurs elements d'un ecran.
///
/// Implementation a controleur unique (pas de Timer externe) : robuste en test
/// et auto-disposee. L'enfant reste toujours dans l'arbre (opacite animee) donc
/// reste trouvable/tappable pendant l'animation.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    // Le delai est encode comme la premiere portion de l'intervalle, ce qui
    // evite un Timer separe.
    final start = total.inMilliseconds == 0
        ? 0.0
        : widget.delay.inMilliseconds / total.inMilliseconds;
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - _animation.value) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
