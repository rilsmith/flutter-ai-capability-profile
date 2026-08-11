import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/team_radar_tab.dart';

void main() {
  group('OAuth configuration is not hardcoded', () {
    test('auth_notifier.dart reads client ID and redirect URI from the environment', () {
      final source = File('lib/providers/auth_notifier.dart').readAsStringSync();

      expect(
        source,
        contains("static const _clientId = String.fromEnvironment('GITHUB_CLIENT_ID');"),
      );
      expect(
        source,
        contains("static const _redirectUri = String.fromEnvironment('REDIRECT_URI');"),
      );
    });

    test('auth_notifier.dart has no hardcoded OAuth client ID or redirect URI', () {
      final source = File('lib/providers/auth_notifier.dart').readAsStringSync();

      // Placeholder values that must never be hardcoded in source.
      expect(source, isNot(contains('YOUR_GITHUB_CLIENT_ID')));
      expect(source, isNot(contains('YOUR_REDIRECT_URI')));
      // No defaultValue fallback for the OAuth constants.
      expect(
        source,
        isNot(contains("String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue:")),
      );
      expect(
        source,
        isNot(contains("String.fromEnvironment('REDIRECT_URI', defaultValue:")),
      );
    });
  });

  group('Required dependencies are declared', () {
    test('pubspec.yaml includes http and web packages', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('http:'));
      expect(pubspec, contains('web:'));
    });
  });

  group('URL utility conditional import files exist', () {
    test('url_utils_stub.dart and url_utils_web.dart are present', () {
      expect(File('lib/utils/url_utils_stub.dart').existsSync(), isTrue);
      expect(File('lib/utils/url_utils_web.dart').existsSync(), isTrue);
    });
  });

  group('Team Capabilities SDLC Coverage', () {
    testWidgets('uses backend aggregate domains and does not fall back to local matrix state',
        (tester) async {
      final dashboardNotifier = DashboardNotifier.forTesting();

      // The local dashboard defaults have nine in-scope, occasional domains,
      // so a fallback would render 9/9. The aggregate override is empty.
      final teamNotifier = TeamNotifier.forTesting(
        aggregateCoverageDomains: [],
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TeamRadarTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty aggregate should show 0/0, proving the dashboard defaults were not used.
      expect(find.text('0/0'), findsOneWidget);
      expect(find.text('9/9'), findsNothing);
    });
  });
}
