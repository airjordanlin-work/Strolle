import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/state/onboarding_state.dart';
import 'package:strolle/theme/app_theme.dart';
import 'package:strolle/widgets/onboarding/goal_step.dart';

void main() {
  Widget harness({
    int dailyGoal = kDefaultDailyGoal,
    DateTime? testDate,
    ValueChanged<int>? onDailyGoalChanged,
    ValueChanged<DateTime>? onTestDateChanged,
    VoidCallback? onFinish,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: GoalStep(
          dailyGoal: dailyGoal,
          testDate: testDate,
          onDailyGoalChanged: onDailyGoalChanged ?? (_) {},
          onTestDateChanged: onTestDateChanged ?? (_) {},
          onFinish: onFinish ?? () {},
          onBack: () {},
        ),
      ),
    );
  }

  testWidgets('renders daily goal presets with the default selected',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    for (final preset in kDailyGoalPresets) {
      expect(find.text('$preset / day'), findsOneWidget);
    }
    final chip = tester.widget<ChoiceChip>(find.byKey(const Key('dailyGoal10')));
    expect(chip.selected, isTrue);
  });

  testWidgets('tapping a preset chip reports it via onDailyGoalChanged',
      (tester) async {
    int? reported;
    await tester.pumpWidget(harness(onDailyGoalChanged: (v) => reported = v));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dailyGoal20')));
    expect(reported, 20);
  });

  testWidgets('shows "days to go" once a test date is set', (tester) async {
    final date = DateTime.now().add(const Duration(days: 30));
    await tester.pumpWidget(harness(testDate: date));
    await tester.pumpAndSettle();
    expect(find.textContaining('days to go'), findsOneWidget);
  });

  testWidgets('Start studying fires onFinish', (tester) async {
    var finished = false;
    await tester.pumpWidget(harness(onFinish: () => finished = true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start studying'));
    expect(finished, isTrue);
  });
}
