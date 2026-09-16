import '../models/progress.dart';
import '../models/streak_status.dart';
import '../state/session_user.dart';

/// Everything [HomeScreen] needs to render, bundled from one call site.
///
/// This is the mock M2-precursor of what a real backend call would
/// return. Nothing in `screens/` imports this file directly — only the
/// router (`app_root.dart` / `main.dart`) does, which is what keeps the
/// screen itself free of data-sourcing decisions.
class HomeScreenData {
  const HomeScreenData({
    required this.userName,
    required this.greeting,
    required this.encouragement,
    required this.streak,
    required this.queueSummary,
    required this.skillStats,
  });

  final String userName;
  final String greeting;
  final String encouragement;
  final StreakStatus streak;
  final SessionQueueSummary queueSummary;
  final List<SkillStat> skillStats;
}

const _encouragementLines = [
  'A few quick reps now beats a long session never.',
  "Small reps add up — you're already ahead of yesterday.",
  'Consistency beats intensity. Keep the streak alive.',
];

/// Morning/afternoon/evening greeting derived from the clock, not
/// hardcoded to one time of day.
String greetingForHour(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Picks a rotating one-liner. Which line to show is a display decision,
/// so it lives here rather than in the widget — the widget just renders
/// whatever string it's given.
String encouragementForDay(DateTime now) =>
    _encouragementLines[now.day % _encouragementLines.length];

HomeScreenData buildMockHomeData(SessionUser? user, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return HomeScreenData(
    userName: user?.name ?? 'there',
    greeting: greetingForHour(at.hour),
    encouragement: encouragementForDay(at),
    streak: StreakStatus.sample(),
    queueSummary: SessionQueueSummary.sample(),
    skillStats: SkillStat.sampleSet(),
  );
}
