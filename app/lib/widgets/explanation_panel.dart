import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown after a wrong answer, before entry is granted.
///
/// Tone matters here more than anywhere else in the app. No red, no X,
/// no "incorrect". The user still gets in; this is the teaching moment,
/// and it is the entire educational payload of the product.
class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({
    super.key,
    required this.explanation,
    required this.correctChoice,
  });

  final String explanation;
  final String correctChoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correctChoice,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            explanation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
