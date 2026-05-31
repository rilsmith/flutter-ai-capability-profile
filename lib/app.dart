import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/dashboard_notifier.dart';
import 'theme/dashboard_theme.dart';
import 'widgets/app_shell.dart';

class AiCapabilityDashboardApp extends StatelessWidget {
  const AiCapabilityDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardNotifier(),
      child: MaterialApp(
        title: 'AI Capability Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: DashboardTheme.background,
          fontFamily: 'Inter',
          colorScheme: ColorScheme.fromSeed(seedColor: DashboardTheme.primary),
        ),
        home: const _HomePage(),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();

    if (!notifier.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const AppShell(),
            ),
          );
        },
      ),
    );
  }
}
