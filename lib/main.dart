import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/dashboard_notifier.dart';

void main() {
  // Required for plugin initialization (like SharedPreferences) before runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => DashboardNotifier(),
      child: const AiCapabilityDashboardApp(),
    ),
  );
}
