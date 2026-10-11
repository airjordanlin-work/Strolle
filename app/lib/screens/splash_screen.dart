import 'package:flutter/material.dart';

/// First thing anyone sees. Shows for a fixed floor, then calls
/// [onFinished] — it does not decide what comes next; that's the
/// router's job (see `app_root.dart`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.displayDuration = const Duration(milliseconds: 1500),
  });

  final VoidCallback onFinished;

  /// A display floor for brand presence, not a stand-in for real
  /// loading — nothing is actually being fetched during this wait.
  /// Overridable so tests don't need to wait 1.5 real seconds.
  final Duration displayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.displayDuration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        // TODO(assets): swap for the real wordmark/logo once designed —
        // it should live at `assets/branding/logo.png` and be added to
        // pubspec.yaml's flutter.assets list alongside questions.json.
        child: Text('Strolle', style: t.displaySmall),
      ),
    );
  }
}
