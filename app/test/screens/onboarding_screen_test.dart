import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/screens/onboarding_screen.dart';
import 'package:strolle/state/onboarding_state.dart';
import 'package:strolle/state/session_user.dart';
import 'package:strolle/theme/app_theme.dart';

void main() {
  testWidgets('walking all five steps and finishing calls onOnboardingComplete',
      (tester) async {
    final state = OnboardingState();
    final auth = MockAuth();
    var loginRequested = false;
    var completed = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: OnboardingScreen(
        state: state,
        auth: auth,
        onLoginRequested: () => loginRequested = true,
        onOnboardingComplete: () => completed = true,
      ),
    ));

    // Step 1: Welcome.
    expect(find.text('Welcome to Strolle'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
    await tester.pumpAndSettle();

    // Step 2: Username.
    await tester.enterText(find.byKey(const Key('usernameField')), 'ryder_t');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 3: Credentials (sign up), drives the mock auth delay.
    await tester.enterText(find.byKey(const Key('emailField')), 'ryder@example.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'supersecret');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump(); // start the mock signup
    await tester.pump(const Duration(milliseconds: 700)); // let it resolve
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isTrue);

    // Step 4: Target score — defaults are already valid, just continue.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 5: Goal — finish.
    await tester.tap(find.widgetWithText(FilledButton, 'Start studying'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(loginRequested, isFalse);
  });

  testWidgets('the welcome step login link fires onLoginRequested', (tester) async {
    var loginRequested = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: OnboardingScreen(
        state: OnboardingState(),
        auth: MockAuth(),
        onLoginRequested: () => loginRequested = true,
        onOnboardingComplete: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Log in'));
    expect(loginRequested, isTrue);
  });
}
