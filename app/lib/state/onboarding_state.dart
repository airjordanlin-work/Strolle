import 'package:flutter/foundation.dart';

/// Which of the two sections the user wants to prioritize first.
/// Feeds a future section-priority signal server-side; purely a
/// motivating framing question at this stage, not an ability judgment.
enum SectionPriority { math, readingWriting }

const int kMinTargetScore = 400;
const int kMaxTargetScore = 1600;
const int kTargetScoreStep = 10;
const int kDefaultTargetScore = 1200;
const int kDefaultDailyGoal = 10;
const List<int> kDailyGoalPresets = [5, 10, 15, 20];

/// Immutable snapshot of everything collected across the five onboarding
/// steps. Replaced wholesale (via [copyWith]) rather than mutated in
/// place, so [OnboardingState] has one obvious place to notify from.
@immutable
class OnboardingAnswers {
  const OnboardingAnswers({
    this.username = '',
    this.email = '',
    this.password = '',
    this.targetScore = kDefaultTargetScore,
    this.sectionPriority,
    this.dailyGoal = kDefaultDailyGoal,
    this.testDate,
  });

  final String username;
  final String email;
  final String password;
  final int targetScore;
  final SectionPriority? sectionPriority;
  final int dailyGoal;
  final DateTime? testDate;

  OnboardingAnswers copyWith({
    String? username,
    String? email,
    String? password,
    int? targetScore,
    SectionPriority? sectionPriority,
    int? dailyGoal,
    DateTime? testDate,
  }) {
    return OnboardingAnswers(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      targetScore: targetScore ?? this.targetScore,
      sectionPriority: sectionPriority ?? this.sectionPriority,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      testDate: testDate ?? this.testDate,
    );
  }
}

/// Holds the in-progress onboarding flow: which step we're on and the
/// answers collected so far, plus the display-only validation rules for
/// each field. Widgets never validate themselves — they show whatever
/// error string (or null) this class hands them.
///
/// "Submit" here just stores data and advances a step index. No network,
/// no persistence — [MockAuth] is the only thing that pretends to talk
/// to a backend, and only at the credentials step.
class OnboardingState extends ChangeNotifier {
  static const stepCount = 5;

  int _stepIndex = 0;
  int get stepIndex => _stepIndex;

  OnboardingAnswers _answers = const OnboardingAnswers();
  OnboardingAnswers get answers => _answers;

  void next() {
    if (_stepIndex >= stepCount - 1) return;
    _stepIndex++;
    notifyListeners();
  }

  void back() {
    if (_stepIndex <= 0) return;
    _stepIndex--;
    notifyListeners();
  }

  void updateUsername(String value) {
    _answers = _answers.copyWith(username: value);
    notifyListeners();
  }

  void updateEmail(String value) {
    _answers = _answers.copyWith(email: value);
    notifyListeners();
  }

  void updatePassword(String value) {
    _answers = _answers.copyWith(password: value);
    notifyListeners();
  }

  void updateTargetScore(int value) {
    _answers = _answers.copyWith(targetScore: value);
    notifyListeners();
  }

  void updateSectionPriority(SectionPriority value) {
    _answers = _answers.copyWith(sectionPriority: value);
    notifyListeners();
  }

  void updateDailyGoal(int value) {
    _answers = _answers.copyWith(dailyGoal: value);
    notifyListeners();
  }

  void updateTestDate(DateTime value) {
    _answers = _answers.copyWith(testDate: value);
    notifyListeners();
  }

  // --- Validation (display-only; widgets just render the result) ---

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

  /// Null means "no error to show" — including for an empty, untouched
  /// field, so the Continue button can be disabled without an error
  /// message flashing before the user has typed anything.
  static String? validateUsername(String value) {
    if (value.isEmpty) return null;
    if (value.length < 3) return 'At least 3 characters.';
    if (value.length > 20) return 'Keep it under 20 characters.';
    if (!_usernamePattern.hasMatch(value)) {
      return 'Letters, numbers, and underscores only.';
    }
    return null;
  }

  static bool isUsernameValid(String value) =>
      value.isNotEmpty && validateUsername(value) == null;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validateEmail(String value) {
    if (value.isEmpty) return null;
    if (!_emailPattern.hasMatch(value)) return 'Enter a valid email.';
    return null;
  }

  static bool isEmailValid(String value) =>
      value.isNotEmpty && validateEmail(value) == null;

  static String? validatePassword(String value) {
    if (value.isEmpty) return null;
    if (value.length < 8) return 'At least 8 characters.';
    return null;
  }

  static bool isPasswordValid(String value) =>
      value.isNotEmpty && validatePassword(value) == null;

  bool get isUsernameStepValid => isUsernameValid(_answers.username);

  bool get isCredentialsStepValid =>
      isEmailValid(_answers.email) && isPasswordValid(_answers.password);
}
