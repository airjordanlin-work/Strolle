import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strolle/app_root.dart';
import 'package:strolle/screens/home_screen.dart';
import 'package:strolle/screens/onboarding_screen.dart';
import 'package:strolle/screens/splash_screen.dart';
import 'package:strolle/state/session_user.dart';
import 'package:strolle/theme/app_theme.dart';

void main() {
  testWidgets('splash routes to onboarding when logged out', (tester) async {
    final auth = MockAuth();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: AppRoot(auth: auth),
    ));

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('splash routes to home when a mock user is already present',
      (tester) async {
    final auth = MockAuth(
      initialUser: const SessionUser(name: 'Ryder', email: 'ryder@example.com'),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: AppRoot(auth: auth),
    ));

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.textContaining('Ryder'), findsOneWidget);
  });
}
