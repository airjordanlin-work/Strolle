import 'package:flutter/material.dart';

/// Editorial motion tokens — home and onboarding only.
///
/// Deliberately separate from `AppTheme.motion` (180ms), which drives
/// the gate screen's near-instant feedback transitions and must stay
/// untouched: the gate is seen 20+ times a day, often mid-frustration,
/// and never gets an entrance animation or a slower feel.
///
/// Editorial = slower, deliberate, confident. No spring/bounce/overshoot.
class AppMotion {
  AppMotion._();

  /// Standard fade+rise reveal for a tile or block of content.
  static const reveal = Duration(milliseconds: 450);

  /// Per-item delay when staggering a sequence of reveals.
  static const staggerStep = Duration(milliseconds: 75);

  /// Tap/press feedback (scale down and back).
  static const press = Duration(milliseconds: 120);

  /// Onboarding step-to-step slide+fade transition.
  static const stepTransition = Duration(milliseconds: 360);

  /// The streak number's one-time count-up on first appearance.
  static const countUp = Duration(milliseconds: 700);

  static const revealCurve = Curves.easeOutCubic;
  static const pressCurve = Curves.easeOut;
  static const stepCurve = Curves.easeOutCubic;

  /// OS-level "reduce motion" — the right default is to fall back to an
  /// instant/opacity-only presentation rather than force motion on
  /// someone who's asked for less of it.
  static bool isReduced(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  /// [duration] if motion is allowed, [Duration.zero] otherwise.
  static Duration durationFor(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
