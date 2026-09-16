import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Step 1 of 5. Pure intro copy plus the two ways out: forward into
/// onboarding, or sideways into the login screen for returning users.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onGetStarted,
    required this.onLogIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Welcome to Strolle', style: t.headlineSmall),
        const SizedBox(height: AppTheme.space16),
        Text(
          'Strolle locks the apps that eat your time behind a few quick '
          "SAT reps. Get one wrong and you still get in — it just costs "
          'a little more next time.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: AppTheme.space32),
        FilledButton(
          onPressed: onGetStarted,
          child: const Text('Get started'),
        ),
        const SizedBox(height: AppTheme.space16),
        Center(
          child: TextButton(
            onPressed: onLogIn,
            child: const Text('I already have an account → Log in'),
          ),
        ),
      ],
    );
  }
}
