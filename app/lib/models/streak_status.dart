/// View-model shape for the home screen's streak signal.
///
/// Deliberately dumb: [currentStreakDays] and [repsToday] are computed
/// upstream (mock data today, the real review queue/backend later) and
/// handed in ready to display. The widget does no counting.
class StreakStatus {
  const StreakStatus({
    required this.currentStreakDays,
    required this.repsToday,
    required this.dailyGoal,
  });

  final int currentStreakDays;
  final int repsToday;
  final int dailyGoal;

  bool get isSafeToday => repsToday >= dailyGoal;

  int get repsRemainingToday => (dailyGoal - repsToday).clamp(0, dailyGoal);

  static StreakStatus sample() => const StreakStatus(
        currentStreakDays: 7,
        repsToday: 4,
        dailyGoal: 10,
      );
}
