import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/state/onboarding_state.dart';
import 'package:strolle/theme/app_theme.dart';
import 'package:strolle/widgets/onboarding/target_score_step.dart';

void main() {
  Widget harness({
    int targetScore = kDefaultTargetScore,
    SectionPriority? priority,
    ValueChanged<int>? onScoreChanged,
    ValueChanged<SectionPriority>? onPriorityChanged,
    VoidCallback? onNext,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TargetScoreStep(
          targetScore: targetScore,
          priority: priority,
          onScoreChanged: onScoreChanged ?? (_) {},
          onPriorityChanged: onPriorityChanged ?? (_) {},
          onNext: onNext ?? () {},
          onBack: () {},
        ),
      ),
    );
  }

  testWidgets('renders the default target score', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('1200'), findsOneWidget);
  });

  testWidgets('dragging the slider reports a new score via onScoreChanged',
      (tester) async {
    int? reported;
    await tester.pumpWidget(harness(onScoreChanged: (v) => reported = v));
    await tester.pumpAndSettle();

    final slider = find.byKey(const Key('targetScoreSlider'));
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();

    expect(reported, isNotNull);
  });

  testWidgets('tapping a priority card fires onPriorityChanged with the right value',
      (tester) async {
    SectionPriority? chosen;
    await tester.pumpWidget(harness(onPriorityChanged: (v) => chosen = v));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('priorityMath')));
    expect(chosen, SectionPriority.math);

    await tester.tap(find.byKey(const Key('priorityReadingWriting')));
    expect(chosen, SectionPriority.readingWriting);
  });

  testWidgets('Continue always enabled and fires onNext', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onNext: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    expect(tapped, isTrue);
  });
}
