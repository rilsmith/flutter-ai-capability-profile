import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/models/individual_profile.dart';
import 'package:ai_capability_dashboard/models/team_profile.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/app_shell.dart';
import 'package:ai_capability_dashboard/widgets/interactive_radar_chart.dart';
import 'package:ai_capability_dashboard/widgets/team_radar_tab.dart';

Map<String, dynamic> _validSubmission({
  required String uid,
  String name = 'Teammate',
  String email = 'teammate@example.com',
  List<double>? scores,
}) {
  final dimensions = defaultDashboardData.dimensions.map((d) {
    final score = scores != null && d.id - 1 < scores.length
        ? scores[d.id - 1]
        : d.score;
    return d.copyWith(score: score).toJson();
  }).toList();

  final applicationDomains = defaultDashboardData.applicationDomains.map((d) {
    return d.copyWith(involvement: DomainInvolvement.regular).toJson();
  }).toList();

  return {
    'id': 'sub-$uid',
    'user_uid': uid,
    'user_email': email,
    'user_display_name': name,
    'manager_uid': 'manager-a',
    'department_number': '12345',
    'submitted_at': '2024-01-01T00:00:00Z',
    'payload': {
      'title': 'Agentic Engineering Capability Profile',
      'subtitle': 'Assessing 5 capability dimensions',
      'intro': '',
      'dimensions': dimensions,
      'applicationDomains': applicationDomains,
      'maturityScale': defaultDashboardData.maturityScale.map((m) => m.toJson()).toList(),
      'howToRead': '',
      'applicationHowToRead': '',
      'applicationMatrixHowToRead': '',
      'tiers': {
        'high': {'label': 'High (4.0-5.0)', 'color': '#16A34A', 'min': 4.0},
        'medium': {'label': 'Medium (2.5-3.9)', 'color': '#CA8A04', 'min': 2.5},
        'low': {'label': 'Low (1.0-2.4)', 'color': '#DC2626', 'min': 1.0},
      },
      'maxScore': defaultDashboardData.maxScore,
    },
  };
}

Map<String, dynamic> _corruptedSubmission({
  required String uid,
  String name = 'Corrupted',
}) {
  return {
    'id': 'sub-$uid',
    'user_uid': uid,
    'user_email': '$uid@example.com',
    'user_display_name': name,
    'manager_uid': 'manager-a',
    'department_number': '12345',
    'submitted_at': '2024-01-01T00:00:00Z',
    'payload': {
      'dimensions': 'not-a-list',
    },
  };
}

Map<String, dynamic> _aggregateResponse({
  required int memberCount,
  required List<Map<String, dynamic>> domains,
}) {
  return {
    'member_count': memberCount,
    'dimensions': defaultDashboardData.dimensions.map((d) => {
      'id': d.id,
      'name': d.name,
      'color': d.color,
      'average': 3.0,
    }).toList(),
    'domains': domains,
  };
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('TeamNotifier.fetchTeamData', () {
    testWidgets('parses team submissions and aggregate data', (tester) async {
      final teamBody = {
        'submissions': [
          _validSubmission(uid: 'alice', name: 'Alice', scores: [5, 4, 3, 2, 1]),
          _validSubmission(uid: 'bob', name: 'Bob', scores: [1, 2, 3, 4, 5]),
        ],
      };
      final aggregateBody = _aggregateResponse(
        memberCount: 2,
        domains: defaultDashboardData.applicationDomains.map((d) => {
          'id': d.id,
          'name': d.name,
          'shortName': d.shortName,
          'involvement_average': 1.5,
          'value_average': 1.0,
          'confidence_average': 1.0,
          'in_scope_count': 1,
          'active_count': 1,
          'not_applicable_count': 0,
        }).toList(),
      );

      int teamRequestCount = 0;
      int aggregateRequestCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          teamRequestCount++;
          return http.Response(jsonEncode(teamBody), 200);
        }
        if (request.url.path == '/api/submissions/team/aggregate') {
          aggregateRequestCount++;
          return http.Response(jsonEncode(aggregateBody), 200);
        }
        return http.Response('Not found', 404);
      });

      final notifier = TeamNotifier(httpClient: mockClient);
      await notifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(teamRequestCount, 1);
      expect(aggregateRequestCount, 1);
      expect(notifier.memberCount, 2);
      expect(notifier.aggregateMemberCount, 2);
      expect(notifier.profile.members[0].name, 'Alice');
      expect(notifier.profile.members[1].name, 'Bob');
      expect(notifier.aggregateCoverageDomains, isNotEmpty);
      expect(notifier.warnings, isEmpty);
      expect(notifier.error, isNull);
      expect(notifier.loading, isFalse);
    });

    testWidgets('handles corrupted teammate submission as warning', (tester) async {
      final teamBody = {
        'submissions': [
          _validSubmission(uid: 'alice', name: 'Alice'),
          _corruptedSubmission(uid: 'bob', name: 'Bob'),
        ],
      };
      final aggregateBody = _aggregateResponse(
        memberCount: 2,
        domains: defaultDashboardData.applicationDomains.map((d) => {
          'id': d.id,
          'name': d.name,
          'shortName': d.shortName,
          'involvement_average': 1.0,
          'value_average': 0.0,
          'confidence_average': 0.0,
          'in_scope_count': 1,
          'active_count': 0,
          'not_applicable_count': 0,
        }).toList(),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          return http.Response(jsonEncode(teamBody), 200);
        }
        if (request.url.path == '/api/submissions/team/aggregate') {
          return http.Response(jsonEncode(aggregateBody), 200);
        }
        return http.Response('Not found', 404);
      });

      final notifier = TeamNotifier(httpClient: mockClient);
      await notifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(notifier.memberCount, 1);
      expect(notifier.profile.members[0].name, 'Alice');
      expect(notifier.warnings, isNotEmpty);
      expect(notifier.warnings.first, contains('Bob'));
      expect(notifier.warnings.first, contains('invalid submission'));
      expect(notifier.error, isNull);
      expect(notifier.loading, isFalse);
    });

    testWidgets('sets error when team endpoint fails', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          return http.Response(jsonEncode({'error': 'Server error'}), 500);
        }
        return http.Response('Not found', 404);
      });

      final notifier = TeamNotifier(httpClient: mockClient);
      await notifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(notifier.error, isNotNull);
      expect(notifier.error, contains('500'));
      expect(notifier.memberCount, 0);
      expect(notifier.loading, isFalse);
    });

    testWidgets('sets error when aggregate endpoint fails', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          return http.Response(jsonEncode({'submissions': []}), 200);
        }
        if (request.url.path == '/api/submissions/team/aggregate') {
          return http.Response(jsonEncode({'error': 'Server error'}), 500);
        }
        return http.Response('Not found', 404);
      });

      final notifier = TeamNotifier(httpClient: mockClient);
      await notifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(notifier.error, isNotNull);
      expect(notifier.error, contains('500'));
      expect(notifier.loading, isFalse);
    });
  });

  group('TeamRadarTab', () {
    testWidgets('renders coverage, radar, and member list from backend data', (tester) async {
      final aggregateDomains = defaultDashboardData.applicationDomains
          .map(
            (d) => ApplicationDomain(
              id: d.id,
              name: d.name,
              shortName: d.shortName,
              applicability: DomainApplicability.inScope,
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
            IndividualProfile(name: 'Alice', scores: [5, 4, 3, 2, 1]),
            IndividualProfile(name: 'Bob', scores: [1, 2, 3, 4, 5]),
          ],
        ),
        aggregateCoverageDomains: aggregateDomains,
        aggregateMemberCount: 2,
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
      expect(find.text('Team Radar — 2 members'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Alice'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Bob'), findsOneWidget);
      expect(find.byType(InteractiveRadarChart), findsOneWidget);
      expect(find.text('No team submissions yet'), findsNothing);
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
      expect(find.byType(InteractiveRadarChart), findsNothing);
      expect(find.text('Team Radar'), findsOneWidget);
      expect(find.text('Team Radar — 0 members'), findsNothing);
    });

    testWidgets('shows error state with retry button', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        warnings: [],
      );
      teamNotifier.debugSetError('Failed to load team aggregate (500)');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TeamRadarTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load team data'), findsOneWidget);
      expect(find.text('Failed to load team aggregate (500)'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(InteractiveRadarChart), findsNothing);
    });

    testWidgets('shows warning banner for corrupted teammate data', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [IndividualProfile(name: 'Alice', scores: [3, 3, 3, 3, 3])],
        ),
        aggregateCoverageDomains: defaultDashboardData.applicationDomains
            .map(
              (d) => ApplicationDomain(
                id: d.id,
                name: d.name,
                shortName: d.shortName,
                applicability: DomainApplicability.inScope,
                involvement: DomainInvolvement.regular,
                value: DomainSignal.moderate,
                confidence: DomainSignal.moderate,
                capabilityIds: const [],
              ),
            )
            .toList(),
        aggregateMemberCount: 2,
        warnings: ['Bob: invalid submission (type mismatch)'],
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

      expect(find.text('1 teammate submission could not be loaded'), findsOneWidget);
      expect(find.text('Bob: invalid submission (type mismatch)'), findsOneWidget);
      expect(find.byType(InteractiveRadarChart), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Alice'), findsOneWidget);
    });

    testWidgets('selecting a member switches radar to individual view', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [
            IndividualProfile(name: 'Alice', scores: [5, 4, 3, 2, 1]),
            IndividualProfile(name: 'Bob', scores: [1, 2, 3, 4, 5]),
          ],
        ),
        aggregateCoverageDomains: defaultDashboardData.applicationDomains
            .map(
              (d) => ApplicationDomain(
                id: d.id,
                name: d.name,
                shortName: d.shortName,
                applicability: DomainApplicability.inScope,
                involvement: DomainInvolvement.regular,
                value: DomainSignal.moderate,
                confidence: DomainSignal.moderate,
                capabilityIds: const [],
              ),
            )
            .toList(),
        aggregateMemberCount: 2,
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

      expect(find.text('Team Radar — 2 members'), findsOneWidget);
      expect(find.text('Alice — Individual View'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(InkWell, 'Alice'));
      await tester.tap(find.widgetWithText(InkWell, 'Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Alice — Individual View'), findsOneWidget);
      expect(find.text('Show team average'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(InkWell, 'Alice'));
      await tester.tap(find.widgetWithText(InkWell, 'Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Team Radar — 2 members'), findsOneWidget);
      expect(find.text('Alice — Individual View'), findsNothing);
    });

    testWidgets('shows loading state while fetching', (tester) async {
      final teamNotifier = TeamNotifier.forTesting();
      teamNotifier.debugSetLoading(true);

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
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(InteractiveRadarChart), findsNothing);
    });

    testWidgets('preserves selected member across tab switches', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );
      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [
            IndividualProfile(name: 'Alice', scores: [5, 4, 3, 2, 1]),
            IndividualProfile(name: 'Bob', scores: [1, 2, 3, 4, 5]),
          ],
        ),
        aggregateCoverageDomains: defaultDashboardData.applicationDomains
            .map(
              (d) => ApplicationDomain(
                id: d.id,
                name: d.name,
                shortName: d.shortName,
                applicability: DomainApplicability.inScope,
                involvement: DomainInvolvement.regular,
                value: DomainSignal.moderate,
                confidence: DomainSignal.moderate,
                capabilityIds: const [],
              ),
            )
            .toList(),
        aggregateMemberCount: 2,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Team Capabilities tab.
      await tester.tap(find.text('Team Capabilities'));
      await tester.pumpAndSettle();
      expect(find.text('Team Radar — 2 members'), findsOneWidget);

      // Select Alice.
      await tester.ensureVisible(find.widgetWithText(InkWell, 'Alice'));
      await tester.tap(find.widgetWithText(InkWell, 'Alice'));
      await tester.pumpAndSettle();
      expect(find.text('Alice — Individual View'), findsOneWidget);

      // Switch to SDLC Matrix tab and back.
      await tester.tap(find.text('SDLC Matrix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team Capabilities'));
      await tester.pumpAndSettle();

      // Selection should be preserved.
      expect(find.text('Alice — Individual View'), findsOneWidget);
    });
  });
}
