import 'package:flutter/material.dart';
import '../models/progress.dart';
import '../models/streak_status.dart';
import '../theme/app_theme.dart';

/// The calm surface. New material is introduced here, never at the gate.
///
/// Design intent: a page from a well-set study journal, not a dashboard.
/// Pure widget — every value it shows comes in via constructor, every
/// interaction goes out via callback. The router/mock data source
/// (`data/mock_home_data.dart`) is what actually assembles these values.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.encouragement,
    required this.streak,
    required this.queueSummary,
    required this.skillStats,
    this.onStartSession,
    this.onShareProgress,
  });

  final String userName;
  final String greeting;
  final String encouragement;
  final StreakStatus streak;
  final SessionQueueSummary queueSummary;
  final List<SkillStat> skillStats;
  final VoidCallback? onStartSession;
  final VoidCallback? onShareProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter, 32, AppTheme.gutter, 56),
            children: [
              _Header(
                greeting: greeting,
                userName: userName,
                encouragement: encouragement,
              ),
              const SizedBox(height: 28),
              _StreakSignal(streak: streak, onShareProgress: onShareProgress),
              const SizedBox(height: 32),
              _SessionInvite(
                  summary: queueSummary, onStartSession: onStartSession),
              const SizedBox(height: 44),
              _ProgressSection(stats: skillStats),
              const SizedBox(height: 44),
              _WeeklyRepsFooter(summary: queueSummary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.userName,
    required this.encouragement,
  });

  final String greeting;
  final String userName;
  final String encouragement;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $userName', style: t.displaySmall),
        const SizedBox(height: 10),
        Text(encouragement, style: t.bodyMedium),
      ],
    );
  }
}

/// The emotional centerpiece: reps have to visibly accumulate or the
/// gate questions read as pure tax. Celebratory, calm, never red — a
/// missed day is a nudge, not a failure state.
class _StreakSignal extends StatelessWidget {
  const _StreakSignal({required this.streak, this.onShareProgress});

  final StreakStatus streak;
  final VoidCallback? onShareProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radius + 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        color: scheme.primary, size: 22),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${streak.currentStreakDays} day streak',
                        style: t.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  streak.isSafeToday
                      ? 'Streak safe today'
                      : '${streak.repsRemainingToday} reps to keep it',
                  style: t.bodyMedium?.copyWith(color: scheme.primary),
                ),
              ],
            ),
          ),
          if (onShareProgress != null)
            IconButton(
              key: const Key('shareProgressButton'),
              tooltip: 'Share my progress',
              onPressed: onShareProgress,
              icon: Icon(Icons.ios_share, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _SessionInvite extends StatelessWidget {
  const _SessionInvite({required this.summary, this.onStartSession});

  final SessionQueueSummary summary;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final empty = summary.totalDue == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 24),
        Text(
          empty ? 'Queue is empty' : '${summary.totalDue} due for a first look',
          style: t.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(summary.dueDescription, style: t.bodyMedium),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: empty
              ? null
              : (onStartSession ??
                  () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Session flow not wired up yet.')),
                      )),
          child: const Text('Start session'),
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.stats});
  final List<SkillStat> stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW YOU’RE DOING', style: t.labelSmall),
        const SizedBox(height: 20),
        for (final s in stats) ...[
          _SkillBar(stat: s),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.stat});
  final SkillStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final up = stat.trendDelta >= 0;
    final trendColor = up ? scheme.primary : scheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(stat.name, style: t.titleMedium)),
            Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12, color: trendColor),
            const SizedBox(width: 3),
            Text(
              '${up ? '+' : ''}${(stat.trendDelta * 100).round()}%',
              style: t.bodyMedium
                  ?.copyWith(color: trendColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: stat.accuracy.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: scheme.outlineVariant),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(stat.accuracy * 100).round()}% accuracy  ·  '
          '${stat.repsLogged} reps',
          style: t.bodyMedium?.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

/// Seven-day rep squares. Split out from the streak signal so the streak
/// (celebratory, front and center) and the raw weekly log (quiet detail)
/// don't compete for attention.
class _WeeklyRepsFooter extends StatelessWidget {
  const _WeeklyRepsFooter({required this.summary});
  final SessionQueueSummary summary;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THIS WEEK', style: t.labelSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${summary.repsThisWeek} reps', style: t.bodyMedium),
            const Spacer(),
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: summary.activeDays[i]
                            ? scheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: summary.activeDays[i]
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: 1.3,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_labels[i],
                        style: t.labelSmall?.copyWith(letterSpacing: 0)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
