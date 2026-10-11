import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../theme/motion.dart';

/// Fades + rises [child] in once, the first time it scrolls into view.
///
/// This is what unifies "on home-screen load" and "on scroll" into one
/// mechanism: whatever is already on-screen at mount reports visible on
/// the very next frame (so it plays as part of the load-time cascade,
/// staggered by [index]); whatever starts below the fold simply reports
/// visible later, whenever the user scrolls to it, and plays the same
/// reveal at that point. Either way it fires exactly once — a `_shown`
/// flag guards against replaying on rebuild or re-entering the viewport.
class RevealOnVisible extends StatefulWidget {
  const RevealOnVisible({
    super.key,
    required this.id,
    required this.child,
    this.index = 0,
  });

  /// Unique within the scrollable it lives in — becomes the
  /// [VisibilityDetector] key.
  final String id;

  final Widget child;

  /// Position in a staggered sequence; multiplied by
  /// [AppMotion.staggerStep] as an additional delay once visible.
  final int index;

  @override
  State<RevealOnVisible> createState() => _RevealOnVisibleState();
}

class _RevealOnVisibleState extends State<RevealOnVisible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.reveal);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.revealCurve);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(_fade);
  }

  void _onVisibility(VisibilityInfo info) {
    if (_shown || info.visibleFraction < 0.2) return;
    _shown = true;

    if (AppMotion.isReduced(context)) {
      _controller.value = 1;
      return;
    }
    Future.delayed(AppMotion.staggerStep * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.id),
      onVisibilityChanged: _onVisibility,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
