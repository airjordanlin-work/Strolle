import 'package:flutter/material.dart';
import '../../theme/motion.dart';

/// Wraps any tappable [child] with a small, warm press response — a
/// gentle scale-down while held, released smoothly. Purely visual: uses
/// [Listener] (raw pointer events) rather than a [GestureDetector], so
/// it never competes with the child's own tap recognizer for the
/// gesture arena.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.scale = 0.98});

  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed && !AppMotion.isReduced(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.pressCurve,
        child: widget.child,
      ),
    );
  }
}
