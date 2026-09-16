import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Applies to every test under `app/test/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Without this, GoogleFonts tries to fetch font files over the network
  // on first use, which is flaky/slow in CI — force the bundled-fallback
  // path instead so widget tests stay deterministic.
  GoogleFonts.config.allowRuntimeFetching = false;

  // visibility_detector normally batches visibility checks on a
  // recurring Timer.periodic, which never completes and would otherwise
  // leak a pending timer into every test that pumps a RevealOnVisible
  // widget. Zero makes it check synchronously after each frame instead —
  // the documented fix for using this package in widget tests.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  return testMain();
}
