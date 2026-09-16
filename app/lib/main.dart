import 'package:flutter/material.dart';
import 'app_root.dart';
import 'data/question_repository.dart';
import 'screens/gate_screen.dart';
import 'services/gate_channel.dart';
import 'state/session_user.dart';
import 'theme/app_theme.dart';

const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = QuestionRepository();
  await repo.load();

  // MOCK — replaced by real Supabase Auth in M2+. See state/session_user.dart.
  final auth = MockAuth();

  GateChannel.onGateRequested((package) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => GateScreen(repo: repo, blockedPackage: package),
        fullscreenDialog: true,
      ),
    );
  });

  runApp(GatekeeperApp(auth: auth));
}

class GatekeeperApp extends StatelessWidget {
  final MockAuth auth;
  const GatekeeperApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Strolle',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: AppRoot(auth: auth),
    );
  }
}
