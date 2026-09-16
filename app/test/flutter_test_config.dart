import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

/// Applies to every test under `app/test/`. Without this, GoogleFonts
/// tries to fetch font files over the network on first use, which is
/// flaky/slow in CI — force the bundled-fallback path instead so widget
/// tests stay deterministic.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  return testMain();
}
