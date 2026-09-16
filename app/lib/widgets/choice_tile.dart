import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ChoiceState { idle, selected, correct, wrong }

/// One answer choice.
///
/// Uses AnimatedContainer rather than an animation package: the state
/// change is a colour and border tween, which the framework does for
/// free. Reaching for a dependency here would add weight for nothing.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, fg, border) = switch (state) {
      ChoiceState.idle => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          Colors.transparent,
        ),
      ChoiceState.selected => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          scheme.primary,
        ),
      // Forest is the designated "correct/positive" token — not a
      // separate success green — so this stays inside the two-accent
      // discipline.
      ChoiceState.correct => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          scheme.primary,
        ),
      // Muted, not alarming. A wrong answer still gets you in, so it
      // should not look like a failure state.
      ChoiceState.wrong => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          scheme.outlineVariant,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          child: AnimatedContainer(
            duration: AppTheme.motion,
            curve: Curves.easeOut,
            constraints:
                const BoxConstraints(minHeight: AppTheme.tapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space12,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: border, width: 1.5),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
