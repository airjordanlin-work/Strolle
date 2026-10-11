import 'package:flutter/foundation.dart';

/// The signed-in user, or null if signed out.
class SessionUser {
  const SessionUser({required this.name, required this.email});

  final String name;
  final String email;
}

/// MOCK. Stands in for Supabase Auth until M2 wires up the real backend
/// (see root CLAUDE.md — server-authoritative state, `auth.uid()` RLS).
///
/// Nothing here talks to a network. It simulates latency with a short
/// delay and then flips in-memory state, so the onboarding/login screens
/// have something real to await and the rest of the app has a session to
/// route on. Replace the bodies of [signUp]/[logIn]/[logOut] with real
/// Supabase Auth calls when that lands; the public shape shouldn't need
/// to change.
class MockAuth extends ChangeNotifier {
  MockAuth({SessionUser? initialUser}) : _currentUser = initialUser;

  SessionUser? _currentUser;
  SessionUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static const _simulatedLatency = Duration(milliseconds: 600);

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(_simulatedLatency);
    _currentUser = SessionUser(name: username, email: email);
    notifyListeners();
  }

  Future<void> logIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(_simulatedLatency);
    _currentUser = SessionUser(name: _nameFromEmail(email), email: email);
    notifyListeners();
  }

  Future<void> logOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
    notifyListeners();
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return local;
    return local[0].toUpperCase() + local.substring(1);
  }
}
