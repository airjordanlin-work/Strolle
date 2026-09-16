import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/state/onboarding_state.dart';
import 'package:strolle/theme/app_theme.dart';
import 'package:strolle/widgets/onboarding/username_step.dart';

void main() {
  Widget harness({
    required String username,
    required ValueChanged<String> onChanged,
    required VoidCallback onNext,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: UsernameStep(
          username: username,
          error: OnboardingState.validateUsername(username),
          isValid: OnboardingState.isUsernameValid(username),
          onChanged: onChanged,
          onNext: onNext,
          onBack: () {},
        ),
      ),
    );
  }

  testWidgets('Continue is disabled for an invalid username', (tester) async {
    await tester.pumpWidget(harness(username: 'ab', onChanged: (_) {}, onNext: () {}));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('At least 3 characters.'), findsOneWidget);
  });

  testWidgets('Continue is enabled once the username is valid, and onNext fires',
      (tester) async {
    var nextTapped = false;
    await tester.pumpWidget(
      harness(username: 'ryder_t', onChanged: (_) {}, onNext: () => nextTapped = true),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    expect(nextTapped, isTrue);
  });

  testWidgets('typing reports every change via onChanged', (tester) async {
    String? lastValue;
    await tester.pumpWidget(
      harness(username: '', onChanged: (v) => lastValue = v, onNext: () {}),
    );

    await tester.enterText(find.byKey(const Key('usernameField')), 'ryder');
    expect(lastValue, 'ryder');
  });
}
