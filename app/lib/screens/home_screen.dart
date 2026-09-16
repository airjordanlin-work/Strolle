import 'package:flutter/material.dart';
import '../models/progress.dart';
import '../models/section_priority.dart';
import '../models/streak_status.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_tile.dart';

/// The calm surface. New material is introduced here, never at the gate.
///
/// Design intent: a curated bento-grid workspace, not a dashboard —
/// modular flat tiles of varying size, hierarchy carried by scale and
/// spacing rather than shadow or color noise. Pure widget — every value
/// it shows comes in via constructor, every interaction goes out via
/// callback. The router/mock data source (`data/mock_home_data.dart`) is
/// what actually assembles these values.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.encouragement,
    required this.streak,
    required this.queueSummary,
    required this.skillStats,
    required this.targetScore,
    required this.sectionPriority,
    this.onStartSession,
    this.onShareProgress,
  });

  final String userName;
  final String greeting;
  final String encouragement;
  final StreakStatus streak;
  final SessionQueueSummary queueSummary;
  final List<SkillStat> skillStats;
  final int targetScore;
  final SectionPriority sectionPriority;
  final VoidCallback? onStartSession;
  final VoidCallback? onShareProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter, AppTheme.space32, AppTheme.gutter, AppTheme.space32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  greeting: greeting,
                  userName: userName,
                  encouragement: encouragement,
                ),
                const SizedBox(height: AppTheme.space24),
                _StreakHeroTile(streak: streak, onShareProgress: onShareProgress),
                const SizedBox(height: AppTheme.space12),
                _StartSessionTile(
                    summary: queueSummary, onStartSession: onStartSession),
                const SizedBox(height: AppTheme.space12),
                _ProgressTile(stats: skillStats),
                const SizedBox(height: AppTheme.space12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _WeeklyRepsTile(summary: queueSummary),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      flex: 2,
                      child: _ScoreGoalTile(
                        targetScore: targetScore,
                        priority: sectionPriority,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        Text('$greeting, $userName', style: t.headlineSmall),
        const SizedBox(height: AppTheme.space8),
        Text(encouragement, style: t.bodyMedium),
      ],
    );
  }
}

/// The hero tile — the emotional centerpiece, per principle 6 ("reps not
/// tolls"). This is the one place Amber leads: the streak number is the
/// only reward moment on the screen. Celebratory but calm, never red.
class _StreakHeroTile extends StatelessWidget {
  const _StreakHeroTile({required this.streak, this.onShareProgress});

  final StreakStatus streak;
  final VoidCallback? onShareProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final amber = Theme.of(context).extension<AppTokens>()!.amber;

    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department, color: amber, size: 28),
              const SizedBox(width: AppTheme.space8),
              Text('Streak', style: t.titleMedium),
              const Spacer(),
              if (onShareProgress != null)
                IconButton(
                  key: const Key('shareProgressButton'),
                  tooltip: 'Share my progress',
                  onPressed: onShareProgress,
                  icon: Icon(Icons.ios_share, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${streak.currentStreakDays}',
                style: t.displaySmall?.copyWith(color: amber),
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                streak.currentStreakDays == 1 ? 'day' : 'days',
                style: t.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            streak.isSafeToday
                ? 'Streak safe today'
                : '${streak.repsRemainingToday} reps to keep it',
            style: t.bodyMedium?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _StartSessionTile extends StatelessWidget {
  const _StartSessionTile({required this.summary, this.onStartSession});

  final SessionQueueSummary summary;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final empty = summary.totalDue == 0;

    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            empty ? 'Queue is empty' : '${summary.totalDue} due for a first look',
            style: t.titleMedium,
          ),
          const SizedBox(height: AppTheme.space4),
          Text(summary.dueDescription, style: t.bodyMedium),
          const SizedBox(height: AppTheme.space16),
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
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.stats});
  final List<SkillStat> stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW YOU’RE DOING', style: t.labelMedium),
          const SizedBox(height: AppTheme.space16),
          for (final s in stats) ...[
            _SkillBar(stat: s),
            const SizedBox(height: AppTheme.space16),
          ],
        ],
      ),
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
    // scheme.error maps to Ink, not red — a dip in accuracy is data, not
    // a failure state.
    final trendColor = up ? scheme.primary : scheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(stat.name, style: t.titleMedium)),
            Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12, color: trendColor),
            const SizedBox(width: AppTheme.space4),
            Text(
              '${up ? '+' : ''}${(stat.trendDelta * 100).round()}%',
              style: t.labelLarge?.copyWith(color: trendColor),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
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
        const SizedBox(height: AppTheme.space8),
        Text(
          '${(stat.accuracy * 100).round()}% accuracy  ·  '
          '${stat.repsLogged} reps',
          style: t.labelMedium,
        ),
      ],
    );
  }
}

/// Seven-day rep squares. Deliberately quiet next to the streak hero —
/// raw log detail, not a reward moment.
class _WeeklyRepsTile extends StatelessWidget {
  const _WeeklyRepsTile({required this.summary});
  final SessionQueueSummary summary;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK', style: t.labelMedium),
          const SizedBox(height: AppTheme.space4),
          Text('${summary.repsThisWeek} reps', style: t.titleMedium),
          const SizedBox(height: AppTheme.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
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
                    const SizedBox(height: AppTheme.space4),
                    Text(_labels[i], style: t.labelMedium),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quiet by design — a reminder of the goal, not a reward. No accent
/// color, no Fraunces number: the streak owns the one "big number" on
/// this screen.
class _ScoreGoalTile extends StatelessWidget {
  const _ScoreGoalTile({required this.targetScore, required this.priority});

  final int targetScore;
  final SectionPriority priority;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return BentoTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GOAL', style: t.labelMedium),
          const SizedBox(height: AppTheme.space4),
          Text('$targetScore', style: t.titleMedium),
          const SizedBox(height: AppTheme.space4),
          Text(_priorityLabel(priority), style: t.bodyMedium),
        ],
      ),
    );
  }
}

String _priorityLabel(SectionPriority priority) => switch (priority) {
      SectionPriority.math => 'Math priority',
      SectionPriority.readingWriting => 'Reading & Writing priority',
    };
