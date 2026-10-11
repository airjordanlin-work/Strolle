import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/screens/splash_screen.dart';
import 'package:strolle/theme/app_theme.dart';

void main() {
  testWidgets('shows the wordmark and does not finish before the display floor',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SplashScreen(
        onFinished: () => finished = true,
        displayDuration: const Duration(milliseconds: 1500),
      ),
    ));

    expect(find.text('Strolle'), findsOneWidget);
    expect(finished, isFalse);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(finished, isFalse);

    // Drain the remaining floor so no timer is left pending at teardown.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('calls onFinished once the display floor elapses', (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SplashScreen(
        onFinished: () => finished = true,
        displayDuration: const Duration(milliseconds: 1500),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(finished, isTrue);
  });
}
