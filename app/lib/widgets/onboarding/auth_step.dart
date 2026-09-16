import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum AuthMode { signUp, logIn }

/// Step 3 of 5 — and, in [AuthMode.logIn], the standalone login screen
/// for returning users. Same widget either way, different labels and
/// submit callback. Fields are UI only: they collect text and forward it
/// via callback. Nothing here authenticates anything.
class AuthStep extends StatefulWidget {
  const AuthStep({
    super.key,
    required this.mode,
    required this.email,
    required this.password,
    required this.emailError,
    required this.passwordError,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    this.onBack,
  });

  final AuthMode mode;
  final String email;
  final String password;
  final String? emailError;
  final String? passwordError;
  final bool canSubmit;
  final bool isSubmitting;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  /// Null hides the Back button (e.g. the standalone login screen).
  final VoidCallback? onBack;

  @override
  State<AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<AuthStep> {
  late final _emailController = TextEditingController(text: widget.email);
  late final _passwordController =
      TextEditingController(text: widget.password);
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isSignUp = widget.mode == AuthMode.signUp;
    final submittable = widget.canSubmit && !widget.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(isSignUp ? 'Create your account' : 'Welcome back', style: t.headlineSmall),
        const SizedBox(height: 8),
        Text(
          isSignUp
              ? "We'll use this to keep your progress in sync."
              : 'Log in to pick up where you left off.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 28),
        TextField(
          key: const Key('emailField'),
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: widget.onEmailChanged,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: widget.emailError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('passwordField'),
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onChanged: widget.onPasswordChanged,
          onSubmitted: (_) {
            if (submittable) widget.onSubmit();
          },
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: widget.passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            if (widget.onBack != null)
              TextButton(
                onPressed: widget.onBack,
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
              onPressed: submittable ? widget.onSubmit : null,
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(isSignUp ? 'Create account' : 'Log in'),
            ),
          ],
        ),
      ],
    );
  }
}
