import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/models/progress.dart';
import 'package:strolle/models/section_priority.dart';
import 'package:strolle/models/streak_status.dart';
import 'package:strolle/screens/home_screen.dart';
import 'package:strolle/theme/app_theme.dart';

void main() {
  Widget harness({VoidCallback? onStartSession, VoidCallback? onShareProgress}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
        userName: 'Ryder',
        greeting: 'Good evening',
        encouragement: 'Small reps add up.',
        streak: StreakStatus.sample(),
        queueSummary: SessionQueueSummary.sample(),
        skillStats: SkillStat.sampleSet(),
        targetScore: 1350,
        sectionPriority: SectionPriority.math,
        onStartSession: onStartSession,
        onShareProgress: onShareProgress ?? () {},
      ),
    );
  }

  testWidgets('renders every section with the mock data supplied', (tester) async {
    // Tall surface so every section is on-screen at once — the real
    // ListView renders fine when scrolled, but findsOneWidget only sees
    // what's actually laid out.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness());

    // a. personal header
    expect(find.text('Good evening, Ryder'), findsOneWidget);
    expect(find.text('Small reps add up.'), findsOneWidget);

    // b. streak signal
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('${StreakStatus.sample().currentStreakDays}'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(find.byKey(const Key('shareProgressButton')), findsOneWidget);

    // c. start session
    expect(find.text('Start session'), findsOneWidget);
    expect(find.textContaining('ready.'), findsOneWidget);

    // d. progress by topic
    expect(find.text('Reading comprehension'), findsOneWidget);
    expect(find.text('Grammar & usage'), findsOneWidget);

    // e. weekly reps tile
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.textContaining('reps'), findsWidgets);

    // score-goal tile
    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('1350'), findsOneWidget);
  });

  testWidgets('Start session fires onStartSession', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onStartSession: () => tapped = true));

    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    expect(tapped, isTrue);
  });

  testWidgets('the share button fires onShareProgress', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onShareProgress: () => tapped = true));

    await tester.tap(find.byKey(const Key('shareProgressButton')));
    expect(tapped, isTrue);
  });
}
