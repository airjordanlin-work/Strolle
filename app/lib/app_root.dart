import 'package:flutter/material.dart';
import 'data/mock_home_data.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'state/onboarding_state.dart';
import 'state/session_user.dart';

enum _RootView { splash, onboarding, login, home }

/// Decides which top-level screen is showing (splash, onboarding, login,
/// or home) and cross-fades between them. This is the "small router
/// widget" the frontend spec calls for — the screens it hosts never make
/// this decision themselves.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.auth});

  final MockAuth auth;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _RootView _view = _RootView.splash;
  final _onboardingState = OnboardingState();

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (widget.auth.isLoggedIn && _view != _RootView.home) {
      setState(() => _view = _RootView.home);
    }
  }

  void _onSplashFinished() {
    setState(() {
      _view = widget.auth.isLoggedIn ? _RootView.home : _RootView.onboarding;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: KeyedSubtree(
        key: ValueKey(_view),
        child: _buildView(),
      ),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case _RootView.splash:
        return SplashScreen(onFinished: _onSplashFinished);
      case _RootView.onboarding:
        return OnboardingScreen(
          state: _onboardingState,
          auth: widget.auth,
          onLoginRequested: () => setState(() => _view = _RootView.login),
          onOnboardingComplete: () => setState(() => _view = _RootView.home),
        );
      case _RootView.login:
        return LoginScreen(
          auth: widget.auth,
          onBack: () => setState(() => _view = _RootView.onboarding),
        );
      case _RootView.home:
        return HomeScreenRoute(user: widget.auth.currentUser);
    }
  }
}

/// Thin adapter: turns the current [SessionUser] into the data
/// [HomeScreen] needs. Kept out of `screens/` so `home_screen.dart`
/// never has to import the mock data source itself.
class HomeScreenRoute extends StatelessWidget {
  const HomeScreenRoute({super.key, required this.user});

  final SessionUser? user;

  @override
  Widget build(BuildContext context) {
    final data = buildMockHomeData(user);
    return HomeScreen(
      userName: data.userName,
      greeting: data.greeting,
      encouragement: data.encouragement,
      streak: data.streak,
      queueSummary: data.queueSummary,
      skillStats: data.skillStats,
      onShareProgress: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not wired up yet.')),
      ),
    );
  }
}
