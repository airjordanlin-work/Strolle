import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/progress.dart';
import '../models/section_priority.dart';
import '../models/streak_status.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../widgets/bento_tile.dart';
import '../widgets/motion/editorial_reveal.dart';
import '../widgets/motion/pressable_scale.dart';
import '../widgets/motion/reveal_on_visible.dart';

/// The calm surface. New material is introduced here, never at the gate.
///
/// Design intent: a curated bento-grid workspace, not a dashboard —
/// modular flat tiles of varying size, hierarchy carried by scale and
/// spacing rather than shadow or color noise. Pure widget — every value
/// it shows comes in via constructor, every interaction goes out via
/// callback. The router/mock data source (`data/mock_home_data.dart`) is
/// what actually assembles these values.
///
/// Entrance is a staggered, editorial reveal (see `theme/motion.dart`):
/// greeting first, then tiles cascading top to bottom, each once per
/// screen open — never replayed on rebuild.
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
                RevealOnVisible(
                  id: 'startSessionTile',
                  index: 1,
                  child: _StartSessionTile(
                      summary: queueSummary, onStartSession: onStartSession),
                ),
                const SizedBox(height: AppTheme.space12),
                RevealOnVisible(
                  id: 'progressTile',
                  index: 2,
                  child: _ProgressTile(stats: skillStats),
                ),
                const SizedBox(height: AppTheme.space12),
                RevealOnVisible(
                  id: 'footerRow',
                  index: 3,
                  child: Row(
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
        EditorialReveal(
          child: Text('$greeting, $userName', style: t.headlineSmall),
        ),
        const SizedBox(height: AppTheme.space8),
        EditorialReveal(
          delay: AppMotion.staggerStep,
          child: Text(encouragement, style: t.bodyMedium),
        ),
      ],
    );
  }
}

/// The hero tile — the emotional centerpiece, per principle 6 ("reps not
/// tolls"). This is the one place Amber leads: the streak number is the
/// only reward moment on the screen. Celebratory but calm, never red.
///
/// Owns its own visibility-triggered reveal rather than wrapping in
/// [RevealOnVisible], since the streak number's one-time count-up needs
/// to start from the same trigger as the tile's fade+rise.
class _StreakHeroTile extends StatefulWidget {
  const _StreakHeroTile({required this.streak, this.onShareProgress});

  final StreakStatus streak;
  final VoidCallback? onShareProgress;

  @override
  State<_StreakHeroTile> createState() => _StreakHeroTileState();
}

class _StreakHeroTileState extends State<_StreakHeroTile>
    with TickerProviderStateMixin {
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: AppMotion.reveal);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _reveal, curve: AppMotion.revealCurve);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(_fade);

  // The one tasteful touch on the emotional peak of the screen: a brief
  // count-up, not a scale-settle too — everywhere else on the screen
  // stays calm so this reads.
  late final AnimationController _count =
      AnimationController(vsync: this, duration: AppMotion.countUp);

  bool _shown = false;

  void _onVisibility(VisibilityInfo info) {
    if (_shown || info.visibleFraction < 0.2) return;
    _shown = true;

    if (AppMotion.isReduced(context)) {
      _reveal.value = 1;
      _count.value = 1;
      return;
    }
    _reveal.forward();
    _count.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final amber = Theme.of(context).extension<AppTokens>()!.amber;
    final streak = widget.streak;

    return VisibilityDetector(
      key: const Key('streakHeroTile'),
      onVisibilityChanged: _onVisibility,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: BentoTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: amber, size: 28),
                    const SizedBox(width: AppTheme.space8),
                    Text('Streak', style: t.titleMedium),
                    const Spacer(),
                    if (widget.onShareProgress != null)
                      PressableScale(
                        child: IconButton(
                          key: const Key('shareProgressButton'),
                          tooltip: 'Share my progress',
                          onPressed: widget.onShareProgress,
                          icon: Icon(Icons.ios_share,
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedBuilder(
                      animation: _count,
                      builder: (context, _) {
                        final shown = (streak.currentStreakDays *
                                Curves.easeOutCubic.transform(_count.value))
                            .round();
                        return Text(
                          '$shown',
                          style: t.displaySmall?.copyWith(color: amber),
                        );
                      },
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
          ),
        ),
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
          PressableScale(
            child: FilledButton(
              onPressed: empty
                  ? null
                  : (onStartSession ??
                      () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Session flow not wired up yet.')),
                          )),
              child: const Text('Start session'),
            ),
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

/// Fills its accuracy bar left-to-right the first time it scrolls into
/// view, rather than arriving pre-full. Owns a small visibility check
/// directly (rather than composing [RevealOnVisible]) since it's gating
/// a fill-width tween, not a fade+rise of the whole row.
class _SkillBar extends StatefulWidget {
  const _SkillBar({required this.stat});
  final SkillStat stat;

  @override
  State<_SkillBar> createState() => _SkillBarState();
}

class _SkillBarState extends State<_SkillBar> {
  bool _visible = false;

  void _onVisibility(VisibilityInfo info) {
    if (_visible || info.visibleFraction < 0.2) return;
    setState(() => _visible = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final stat = widget.stat;
    final up = stat.trendDelta >= 0;
    // scheme.error maps to Ink, not red — a dip in accuracy is data, not
    // a failure state.
    final trendColor = up ? scheme.primary : scheme.error;

    return VisibilityDetector(
      key: Key('skillBar-${stat.name}'),
      onVisibilityChanged: _onVisibility,
      child: Column(
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
            tween: Tween(
              begin: 0,
              end: _visible ? stat.accuracy.clamp(0.0, 1.0) : 0.0,
            ),
            duration: AppMotion.durationFor(context, AppMotion.reveal),
            curve: AppMotion.revealCurve,
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
      ),
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
