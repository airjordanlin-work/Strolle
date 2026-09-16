import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Step 2 of 5. Purely presentational — [error] and [isValid] are
/// computed upstream by `OnboardingState`; this widget just displays
/// them and reports every keystroke via [onChanged]. The
/// [TextEditingController] here is transient UI plumbing (cursor/IME
/// state), not business logic — the source of truth is still whatever
/// calls [onChanged].
class UsernameStep extends StatefulWidget {
  const UsernameStep({
    super.key,
    required this.username,
    required this.error,
    required this.isValid,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  final String username;
  final String? error;
  final bool isValid;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends State<UsernameStep> {
  late final _controller = TextEditingController(text: widget.username);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pick a username', style: t.headlineSmall),
        const SizedBox(height: AppTheme.space8),
        Text(
          'What should we call you? You can change this later.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: AppTheme.space24),
        TextField(
          key: const Key('usernameField'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: widget.onChanged,
          onSubmitted: (_) {
            if (widget.isValid) widget.onNext();
          },
          decoration: InputDecoration(
            labelText: 'Username',
            errorText: widget.error,
          ),
        ),
        const SizedBox(height: AppTheme.space32),
        Row(
          children: [
            TextButton(
              onPressed: widget.onBack,
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, AppTheme.tapTarget),
              ),
              onPressed: widget.isValid ? widget.onNext : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
