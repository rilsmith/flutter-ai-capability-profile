import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/models/individual_profile.dart';
import 'package:ai_capability_dashboard/models/team_profile.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/app_shell.dart';
import 'package:ai_capability_dashboard/widgets/header.dart';
import 'package:ai_capability_dashboard/widgets/sdlc_tab.dart';
import 'package:ai_capability_dashboard/widgets/team_radar_tab.dart';

void main() {
  group('Header', () {
    testWidgets('shows title and subtitle without Actions menu', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Header(
            title: 'Test Title',
            subtitle: 'Test Subtitle',
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.text('Actions'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('SDLCTab', () {
    testWidgets('renders only matrix explanation and matrix card', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => DashboardNotifier.forTesting(),
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How to Read — Capability × Domain'), findsOneWidget);
      expect(find.text('Capability × Domain Links'), findsOneWidget);
      expect(find.text('How to Read — SDLC Coverage'), findsNothing);
      expect(find.text('SDLC Coverage'), findsNothing);
      expect(find.text('SDLC Application'), findsNothing);
    });
  });

  group('TeamRadarTab', () {
    testWidgets('starts with SDLC Coverage and explanation, then radar', (tester) async {
      final aggregateDomains = defaultDashboardData.applicationDomains
          .map(
            (d) => ApplicationDomain(
              id: d.id,
              name: d.name,
              shortName: d.shortName,
              applicability: d.applicability,
              involvement: DomainInvolvement.regular,
              value: DomainSignal.moderate,
              confidence: DomainSignal.moderate,
              capabilityIds: const [],
            ),
          )
          .toList();

      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [
            IndividualProfile(
              name: 'Alice',
              scores: List.filled(5, 3.0),
            ),
          ],
        ),
        aggregateCoverageDomains: aggregateDomains,
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TeamRadarTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How to Read — SDLC Coverage'), findsOneWidget);
      expect(find.text('SDLC Coverage'), findsOneWidget);
      expect(find.text('Team Radar — 1 member'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Member name'), findsNothing);
      expect(find.text('Import / Export'), findsNothing);
      expect(find.text('Export CSV'), findsNothing);
      expect(find.text('Import CSV'), findsNothing);
    });

    testWidgets('shows empty state when no team submissions exist', (tester) async {
      final teamNotifier = TeamNotifier.forTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TeamRadarTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No team submissions yet'), findsOneWidget);
      expect(find.text('Team Radar — 0 members'), findsNothing);
      expect(find.text('Team Radar'), findsOneWidget);
    });
  });

  group('AppShell', () {
    testWidgets('renders three tabs with correct labels and SDLC Matrix first', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SDLC Matrix'), findsOneWidget);
      expect(find.text('Team Capabilities'), findsOneWidget);
      expect(find.text('Profile Insights'), findsOneWidget);
      expect(find.text('SDLC Application'), findsNothing);
      expect(find.text('Actions'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(PopupMenuButton<void>), findsOneWidget);
    });

    testWidgets('user menu is hidden when not authenticated', (tester) async {
      final authNotifier = AuthNotifier.forTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<void>), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('narrow viewport uses dropdown tab selector', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SDLC Matrix'), findsOneWidget);
      expect(find.text('Team Capabilities'), findsOneWidget);
      expect(find.text('Profile Insights'), findsOneWidget);
      expect(find.text('SDLC Application'), findsNothing);
    });
  });
}
