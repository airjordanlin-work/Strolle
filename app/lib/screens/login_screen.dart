import 'package:flutter/material.dart';
import '../state/onboarding_state.dart';
import '../state/session_user.dart';
import '../theme/app_theme.dart';
import '../widgets/onboarding/auth_step.dart';

/// Returning-user login. Wraps the same [AuthStep] widget used at
/// onboarding step 3, in [AuthMode.logIn]. Once [MockAuth.logIn]
/// resolves, the router (which listens to [MockAuth]) is what moves on
/// to home — this screen doesn't decide that itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onBack,
  });

  final MockAuth auth;

  /// "Not you? Back to sign up" — returns to onboarding's welcome step.
  final VoidCallback onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _email = '';
  String _password = '';
  bool _isSubmitting = false;

  bool get _canSubmit =>
      OnboardingState.isEmailValid(_email) &&
      OnboardingState.isPasswordValid(_password);

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await widget.auth.logIn(email: _email, password: _password);
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gutter),
            child: AuthStep(
              mode: AuthMode.logIn,
              email: _email,
              password: _password,
              emailError: OnboardingState.validateEmail(_email),
              passwordError: OnboardingState.validatePassword(_password),
              canSubmit: _canSubmit,
              isSubmitting: _isSubmitting,
              onEmailChanged: (v) => setState(() => _email = v),
              onPasswordChanged: (v) => setState(() => _password = v),
              onSubmit: _submit,
              onBack: widget.onBack,
            ),
          ),
        ),
      ),
    );
  }
}
