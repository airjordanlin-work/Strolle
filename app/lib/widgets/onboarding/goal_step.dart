import 'package:flutter/material.dart';
import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';

/// Step 5 of 5 — the last screen of onboarding. Two commitments: a daily
/// reps goal and a test date. Finishing calls [onFinish], which the flow
/// container wires to "complete onboarding" and a route to home.
class GoalStep extends StatelessWidget {
  const GoalStep({
    super.key,
    required this.dailyGoal,
    required this.testDate,
    required this.onDailyGoalChanged,
    required this.onTestDateChanged,
    required this.onFinish,
    required this.onBack,
  });

  final int dailyGoal;
  final DateTime? testDate;
  final ValueChanged<int> onDailyGoalChanged;
  final ValueChanged<DateTime> onTestDateChanged;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: testDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) onTestDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final daysToGo = testDate?.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Let’s make it a habit', style: t.headlineSmall),
        const SizedBox(height: AppTheme.space8),
        Text(
          'Daily questions goal — this is what keeps your streak alive.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: AppTheme.space16),
        Wrap(
          spacing: AppTheme.space8,
          runSpacing: AppTheme.space8,
          children: [
            for (final preset in kDailyGoalPresets)
              ChoiceChip(
                key: Key('dailyGoal$preset'),
                label: Text('$preset / day'),
                selected: dailyGoal == preset,
                onSelected: (_) => onDailyGoalChanged(preset),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space32),
        Text('When is your test?', style: t.titleMedium),
        const SizedBox(height: AppTheme.space12),
        OutlinedButton(
          key: const Key('testDateButton'),
          onPressed: () => _pickDate(context),
          child: Text(testDate == null ? 'Pick a date' : _formatDate(testDate!)),
        ),
        if (daysToGo != null) ...[
          const SizedBox(height: AppTheme.space8),
          Text(
            daysToGo >= 0
                ? '$daysToGo days to go'
                : 'That date has passed — pick a new one',
            style: t.bodyMedium?.copyWith(color: scheme.primary),
          ),
        ],
        const SizedBox(height: AppTheme.space32),
        Row(
          children: [
            TextButton(
              onPressed: onBack,
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, AppTheme.tapTarget),
              ),
              onPressed: onFinish,
              child: const Text('Start studying'),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}
