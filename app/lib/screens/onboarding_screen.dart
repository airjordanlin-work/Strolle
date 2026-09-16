import 'package:flutter/material.dart';
import '../state/onboarding_state.dart';
import '../state/session_user.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../widgets/onboarding/auth_step.dart';
import '../widgets/onboarding/goal_step.dart';
import '../widgets/onboarding/onboarding_progress.dart';
import '../widgets/onboarding/target_score_step.dart';
import '../widgets/onboarding/username_step.dart';
import '../widgets/onboarding/welcome_step.dart';

/// The five-step onboarding flow. This is the "thin controller" the task
/// calls for: it owns which step is showing and drives [OnboardingState]
/// and [MockAuth], but every step it renders is a pure widget that only
/// knows its own value and callbacks.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.state,
    required this.auth,
    required this.onLoginRequested,
    required this.onOnboardingComplete,
  });

  final OnboardingState state;
  final MockAuth auth;

  /// Welcome step's "I already have an account" link.
  final VoidCallback onLoginRequested;

  /// Fired once the last step's mock signup succeeds.
  final VoidCallback onOnboardingComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isSubmittingSignUp = false;

  // Which way the step transition should slide: 1 for forward (Continue),
  // -1 for back. OnboardingState.notifyListeners() also fires on every
  // keystroke, not just step changes, so this only updates when the step
  // index itself has actually moved.
  late int _lastStepIndex = widget.state.stepIndex;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final newIndex = widget.state.stepIndex;
    if (newIndex != _lastStepIndex) {
      _direction = newIndex > _lastStepIndex ? 1 : -1;
      _lastStepIndex = newIndex;
    }
    setState(() {});
  }

  Widget _stepTransitionBuilder(Widget child, Animation<double> animation) {
    const magnitude = 0.2;
    final isIncoming = child.key == ValueKey(widget.state.stepIndex);
    final edgeOffset = Offset(isIncoming ? _direction * magnitude : -_direction * magnitude, 0);
    final tween = isIncoming
        ? Tween<Offset>(begin: edgeOffset, end: Offset.zero)
        : Tween<Offset>(begin: Offset.zero, end: edgeOffset);

    return SlideTransition(
      position: tween.animate(
        CurvedAnimation(parent: animation, curve: AppMotion.stepCurve),
      ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  Future<void> _submitSignUp() async {
    setState(() => _isSubmittingSignUp = true);
    final answers = widget.state.answers;
    await widget.auth.signUp(
      username: answers.username,
      email: answers.email,
      password: answers.password,
    );
    if (!mounted) return;
    setState(() => _isSubmittingSignUp = false);
    widget.state.next();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingProgress(
                  currentStep: state.stepIndex + 1,
                  totalSteps: OnboardingState.stepCount,
                ),
                const SizedBox(height: AppTheme.space24),
                Expanded(
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: AppMotion.durationFor(context, AppMotion.stepTransition),
                      transitionBuilder: _stepTransitionBuilder,
                      child: KeyedSubtree(
                        key: ValueKey(state.stepIndex),
                        child: _buildStep(state),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingState state) {
    final answers = state.answers;
    switch (state.stepIndex) {
      case 0:
        return WelcomeStep(
          onGetStarted: state.next,
          onLogIn: widget.onLoginRequested,
        );
      case 1:
        return UsernameStep(
          username: answers.username,
          error: OnboardingState.validateUsername(answers.username),
          isValid: state.isUsernameStepValid,
          onChanged: state.updateUsername,
          onNext: state.next,
          onBack: state.back,
        );
      case 2:
        return AuthStep(
          mode: AuthMode.signUp,
          email: answers.email,
          password: answers.password,
          emailError: OnboardingState.validateEmail(answers.email),
          passwordError: OnboardingState.validatePassword(answers.password),
          canSubmit: state.isCredentialsStepValid,
          isSubmitting: _isSubmittingSignUp,
          onEmailChanged: state.updateEmail,
          onPasswordChanged: state.updatePassword,
          onSubmit: _submitSignUp,
          onBack: state.back,
        );
      case 3:
        return TargetScoreStep(
          targetScore: answers.targetScore,
          priority: answers.sectionPriority,
          onScoreChanged: state.updateTargetScore,
          onPriorityChanged: state.updateSectionPriority,
          onNext: state.next,
          onBack: state.back,
        );
      case 4:
        return GoalStep(
          dailyGoal: answers.dailyGoal,
          testDate: answers.testDate,
          onDailyGoalChanged: state.updateDailyGoal,
          onTestDateChanged: state.updateTestDate,
          onFinish: widget.onOnboardingComplete,
          onBack: state.back,
        );
      default:
        throw StateError('Unknown onboarding step ${state.stepIndex}');
    }
  }
}
