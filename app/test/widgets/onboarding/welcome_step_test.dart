import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/theme/app_theme.dart';
import 'package:strolle/widgets/onboarding/welcome_step.dart';

void main() {
  Widget harness({required VoidCallback onGetStarted, required VoidCallback onLogIn}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: WelcomeStep(onGetStarted: onGetStarted, onLogIn: onLogIn),
      ),
    );
  }

  testWidgets('renders intro copy and both actions', (tester) async {
    await tester.pumpWidget(harness(onGetStarted: () {}, onLogIn: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Strolle'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
    expect(find.textContaining('Log in'), findsOneWidget);
  });

  testWidgets('Get started fires onGetStarted', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onGetStarted: () => tapped = true, onLogIn: () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
    expect(tapped, isTrue);
  });

  testWidgets('the login link fires onLogIn', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onGetStarted: () {}, onLogIn: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Log in'));
    expect(tapped, isTrue);
  });
}
