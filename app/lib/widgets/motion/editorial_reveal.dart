import 'package:flutter/material.dart';
import '../../theme/motion.dart';

/// A gentle fade + small upward slide, played once when this widget
/// first mounts (optionally after [delay], for staggering a sequence).
/// Never replays on rebuild — the animation is owned by this State
/// object and only ever driven forward once from [initState].
///
/// Use this for content whose entrance timing is fixed relative to its
/// parent screen (the header, an onboarding step's heading/field/button
/// sequence). For content that may start below the fold, use
/// [RevealOnVisible] instead so it plays on scroll-into-view rather than
/// on a timer that may fire off-screen.
class EditorialReveal extends StatefulWidget {
  const EditorialReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<EditorialReveal> createState() => _EditorialRevealState();
}

class _EditorialRevealState extends State<EditorialReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.reveal);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.revealCurve);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(_fade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't available yet in initState for this widget's
    // InheritedModel-based lookup — didChangeDependencies is the correct
    // place, guarded so it only ever starts once.
    if (_started) return;
    _started = true;

    if (AppMotion.isReduced(context)) {
      _controller.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
