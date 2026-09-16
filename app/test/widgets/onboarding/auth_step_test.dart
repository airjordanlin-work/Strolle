import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/state/onboarding_state.dart';
import 'package:strolle/theme/app_theme.dart';
import 'package:strolle/widgets/onboarding/auth_step.dart';

void main() {
  Widget harness({
    required AuthMode mode,
    String email = '',
    String password = '',
    bool isSubmitting = false,
    ValueChanged<String>? onEmailChanged,
    ValueChanged<String>? onPasswordChanged,
    VoidCallback? onSubmit,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AuthStep(
          mode: mode,
          email: email,
          password: password,
          emailError: OnboardingState.validateEmail(email),
          passwordError: OnboardingState.validatePassword(password),
          canSubmit: OnboardingState.isEmailValid(email) &&
              OnboardingState.isPasswordValid(password),
          isSubmitting: isSubmitting,
          onEmailChanged: onEmailChanged ?? (_) {},
          onPasswordChanged: onPasswordChanged ?? (_) {},
          onSubmit: onSubmit ?? () {},
          onBack: () {},
        ),
      ),
    );
  }

  testWidgets('sign-up mode shows sign-up labels', (tester) async {
    await tester.pumpWidget(harness(mode: AuthMode.signUp));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('log-in mode shows log-in labels', (tester) async {
    await tester.pumpWidget(harness(mode: AuthMode.logIn));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('submit is disabled until email and password are both valid',
      (tester) async {
    await tester.pumpWidget(harness(mode: AuthMode.signUp, email: 'a@b.com', password: ''));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('submit fires onSubmit once fields are valid', (tester) async {
    var submitted = false;
    await tester.pumpWidget(harness(
      mode: AuthMode.signUp,
      email: 'a@b.com',
      password: 'longenough',
      onSubmit: () => submitted = true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    expect(submitted, isTrue);
  });

  testWidgets('typing reports changes via callbacks', (tester) async {
    String? lastEmail;
    String? lastPassword;
    await tester.pumpWidget(harness(
      mode: AuthMode.signUp,
      onEmailChanged: (v) => lastEmail = v,
      onPasswordChanged: (v) => lastPassword = v,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('emailField')), 'ryder@example.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'supersecret');

    expect(lastEmail, 'ryder@example.com');
    expect(lastPassword, 'supersecret');
  });

  testWidgets('password visibility toggle obscures/reveals text', (tester) async {
    await tester.pumpWidget(harness(mode: AuthMode.signUp, password: 'supersecret'));
    await tester.pumpAndSettle();

    TextField passwordField() =>
        tester.widget<TextField>(find.byKey(const Key('passwordField')));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });
}
