import 'package:flutter/material.dart';
import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';

/// Step 4 of 5. Two motivating (not evaluative) questions: a target
/// score and which section matters most right now.
class TargetScoreStep extends StatelessWidget {
  const TargetScoreStep({
    super.key,
    required this.targetScore,
    required this.priority,
    required this.onScoreChanged,
    required this.onPriorityChanged,
    required this.onNext,
    required this.onBack,
  });

  final int targetScore;
  final SectionPriority? priority;
  final ValueChanged<int> onScoreChanged;
  final ValueChanged<SectionPriority> onPriorityChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const divisions =
        (kMaxTargetScore - kMinTargetScore) ~/ kTargetScoreStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What are we aiming for?', style: t.headlineSmall),
        const SizedBox(height: 8),
        Text(
          "Just a target to study toward — not a judgment of where "
          "you're starting.",
          style: t.bodyMedium,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '$targetScore',
            style: t.displaySmall?.copyWith(fontSize: 44, color: scheme.primary),
          ),
        ),
        Slider(
          key: const Key('targetScoreSlider'),
          value: targetScore.toDouble(),
          min: kMinTargetScore.toDouble(),
          max: kMaxTargetScore.toDouble(),
          divisions: divisions,
          label: '$targetScore',
          onChanged: (v) => onScoreChanged(v.round()),
        ),
        const SizedBox(height: 28),
        Text('Which matters most right now?', style: t.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PriorityCard(
                key: const Key('priorityMath'),
                label: 'Math',
                selected: priority == SectionPriority.math,
                onTap: () => onPriorityChanged(SectionPriority.math),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PriorityCard(
                key: const Key('priorityReadingWriting'),
                label: 'Reading & Writing',
                selected: priority == SectionPriority.readingWriting,
                onTap: () => onPriorityChanged(SectionPriority.readingWriting),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppTheme.tapTarget),
              ),
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, AppTheme.tapTarget),
              ),
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTheme.tapTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
