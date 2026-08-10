import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_notifier.dart';
import 'providers/dashboard_notifier.dart';
import 'providers/team_notifier.dart';
import 'theme/dashboard_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/login_screen.dart';

class AiCapabilityDashboardApp extends StatelessWidget {
  const AiCapabilityDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        ChangeNotifierProvider(create: (_) => DashboardNotifier()),
        ChangeNotifierProvider(create: (_) => TeamNotifier()),
      ],
      child: MaterialApp(
        title: 'AI Capability Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: DashboardTheme.background,
          colorScheme: ColorScheme.fromSeed(seedColor: DashboardTheme.primary),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (auth.isLoggedIn) return const _HomePage();
    return const LoginScreen();
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final dashNotifier = context.watch<DashboardNotifier>();
    final teamNotifier = context.watch<TeamNotifier>();

    if (!dashNotifier.initialized || !teamNotifier.initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initializing Dashboard...'),
            ],
          ),
        ),
      );
    }

    return const Scaffold(
      body: AppShell(),
    );
  }
}