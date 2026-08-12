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
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How to Read — AI × SDLC Adoption Matrix'), findsOneWidget);
      expect(find.text('AI × SDLC Adoption Matrix'), findsOneWidget);
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

    testWidgets('SDLC Coverage explanation describes read-only team aggregation', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        aggregateCoverageDomains: [],
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
      expect(
        find.text(
          'SDLC Coverage is a read-only view of how the team uses agents across the software development lifecycle. '
          'The bars reflect the average involvement across the team’s latest submissions, not the current user’s local matrix. '
          'Update coverage in the SDLC Matrix tab and tap Submit to refresh this view.',
        ),
        findsOneWidget,
      );
      expect(find.text('Click a lifecycle bar to cycle agent use'), findsNothing);
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

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 1200)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authNotifier),
              ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
              ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: AppShell()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SDLC Matrix'), findsOneWidget);
      expect(find.text('SDLC Application'), findsNothing);
      expect(find.byType(DropdownButton<int>), findsOneWidget);

      // Open the dropdown and verify all three tab labels are available.
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Team Capabilities'), findsOneWidget);
      expect(find.text('Profile Insights'), findsOneWidget);
    });

    testWidgets('header stacks title and user menu vertically on narrow viewport', (tester) async {
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
        MediaQuery(
          data: const MediaQueryData(size: Size(375, 1200)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authNotifier),
              ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
              ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: AppShell()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final titleFinder = find.text('Agentic Engineering Capability Profile');
      final menuFinder = find.byType(PopupMenuButton<void>);
      expect(titleFinder, findsOneWidget);
      expect(menuFinder, findsOneWidget);

      final titleOffset = tester.getTopLeft(titleFinder);
      final menuOffset = tester.getTopLeft(menuFinder);
      expect(menuOffset.dy, greaterThan(titleOffset.dy));
    });

    testWidgets('header keeps title and user menu horizontal on wide viewport', (tester) async {
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
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 800)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authNotifier),
              ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
              ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: AppShell()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final titleFinder = find.text('Agentic Engineering Capability Profile');
      final menuFinder = find.byType(PopupMenuButton<void>);
      expect(titleFinder, findsOneWidget);
      expect(menuFinder, findsOneWidget);

      final titleOffset = tester.getTopLeft(titleFinder);
      final menuOffset = tester.getTopLeft(menuFinder);
      expect(menuOffset.dy, equals(titleOffset.dy));
    });
  });
}
