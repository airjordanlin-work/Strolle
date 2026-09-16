import 'package:flutter/material.dart';

/// Slim "Step X of N" indicator shown at the top of the onboarding flow.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  /// 1-indexed.
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP $currentStep OF $totalSteps', style: t.labelSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < totalSteps; i++)
              Expanded(
                child: Container(
                  margin:
                      EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < currentStep
                        ? scheme.primary
                        : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
