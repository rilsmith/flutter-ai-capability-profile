import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/profile_tab.dart';
import 'package:ai_capability_dashboard/widgets/sdlc_tab.dart';
import 'package:ai_capability_dashboard/widgets/team_radar_tab.dart';

class _FailingThenSucceedingClient {
  _FailingThenSucceedingClient({required this.successResponse});

  final http.Response successResponse;
  int requestCount = 0;

  Future<http.Response> respond(http.Request request) async {
    requestCount++;
    if (requestCount == 1) {
      throw http.ClientException('Connection refused');
    }
    return successResponse;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('VAL-CROSS-013: offline/network retry behavior', () {
    testWidgets('submission failure shows Retry and succeeds on retry',
        (tester) async {
      final clientHelper = _FailingThenSucceedingClient(
        successResponse: http.Response(
          jsonEncode({
            'id': '123e4567-e89b-12d3-a456-426614174000',
            'submitted_at': '2024-01-01T00:00:00Z',
          }),
          201,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final mockClient = MockClient(clientHelper.respond);

      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );
      final teamNotifier = TeamNotifier.forTesting();

      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider<TeamNotifier>.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Submit; the first request simulates a network failure.
      final submitFinder = find.text('Submit');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // The UI should show a readable network error and a Retry action.
      expect(find.textContaining('Connection refused'), findsWidgets);
      expect(find.text('Retry'), findsWidgets);
      expect(clientHelper.requestCount, 1);

      // Tap Retry; connectivity is "restored" and the second request succeeds.
      final retryFinder = find.text('Retry');
      await tester.ensureVisible(retryFinder.first);
      await tester.tap(retryFinder.first);
      await tester.pumpAndSettle();

      expect(clientHelper.requestCount, 2);
      expect(find.textContaining('Submitted successfully'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsNothing);
    });

    testWidgets('team aggregate failure shows Retry and succeeds on retry',
        (tester) async {
      final teamBody = {
        'submissions': [
          {
            'id': 'sub-alice',
            'user_uid': 'alice',
            'user_email': 'alice@example.com',
            'user_display_name': 'Alice',
            'manager_uid': 'manager-a',
            'department_number': '12345',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': {
              'title': 'Test',
              'subtitle': 'Test',
              'intro': '',
              'dimensions': defaultDashboardData.dimensions.map((d) => d.toJson()).toList(),
              'applicationDomains': defaultDashboardData.applicationDomains
                  .map((d) => d.copyWith(involvement: DomainInvolvement.regular).toJson())
                  .toList(),
              'maturityScale': defaultDashboardData.maturityScale.map((m) => m.toJson()).toList(),
              'howToRead': '',
              'applicationHowToRead': '',
              'applicationMatrixHowToRead': '',
              'tiers': {
                'high': {'label': 'High', 'color': '#16A34A', 'min': 4.0},
                'medium': {'label': 'Medium', 'color': '#CA8A04', 'min': 2.5},
                'low': {'label': 'Low', 'color': '#DC2626', 'min': 1.0},
              },
              'maxScore': defaultDashboardData.maxScore,
            },
          },
        ],
      };
      final aggregateBody = {
        'member_count': 1,
        'dimensions': defaultDashboardData.dimensions.map((d) => {
          'id': d.id,
          'name': d.name,
          'color': d.color,
          'average': 3.0,
        }).toList(),
        'domains': defaultDashboardData.applicationDomains.map((d) => {
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
      };

      int teamRequestCount = 0;
      int aggregateRequestCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          teamRequestCount++;
          return http.Response(jsonEncode(teamBody), 200);
        }
        if (request.url.path == '/api/submissions/team/aggregate') {
          aggregateRequestCount++;
          if (aggregateRequestCount == 1) {
            throw http.ClientException('Connection refused');
          }
          return http.Response(jsonEncode(aggregateBody), 200);
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamNotifier = TeamNotifier(httpClient: mockClient);

      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TeamRadarTab()),
          ),
        ),
      );

      // Trigger the initial fetch; the first request fails.
      teamNotifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(find.text('Unable to load team data'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(teamRequestCount, 1);
      expect(aggregateRequestCount, 1);

      // Tap Retry; the second request succeeds and the radar is rendered.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(teamRequestCount, 2);
      expect(aggregateRequestCount, 2);
      expect(find.text('Unable to load team data'), findsNothing);
      expect(find.textContaining('Connection refused'), findsNothing);
      expect(find.text('Team Radar — 1 member'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Alice'), findsOneWidget);
    });

    testWidgets('profile insights aggregate failure shows Retry and succeeds on retry',
        (tester) async {
      final aggregateBody = {
        'member_count': 1,
        'dimensions': defaultDashboardData.dimensions.map((d) => {
          'id': d.id,
          'name': d.name,
          'color': d.color,
          'average': 3.0,
        }).toList(),
        'domains': defaultDashboardData.applicationDomains.map((d) => {
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
      };

      int teamRequestCount = 0;
      int aggregateRequestCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/submissions/team') {
          teamRequestCount++;
          return http.Response(jsonEncode({'submissions': []}), 200);
        }
        if (request.url.path == '/api/submissions/team/aggregate') {
          aggregateRequestCount++;
          if (aggregateRequestCount == 1) {
            throw http.ClientException('Connection refused');
          }
          return http.Response(jsonEncode(aggregateBody), 200);
        }
        return http.Response('Not found', 404);
      });

      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamNotifier = TeamNotifier(httpClient: mockClient);

      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );

      // Trigger the initial fetch; the first request fails.
      teamNotifier.fetchTeamData('test-token');
      await tester.pumpAndSettle();

      expect(find.text('Unable to load team insights'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(teamRequestCount, 1);
      expect(aggregateRequestCount, 1);

      // Tap Retry; the second request succeeds and the cards are rendered.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(teamRequestCount, 2);
      expect(aggregateRequestCount, 2);
      expect(find.text('Unable to load team insights'), findsNothing);
      expect(find.textContaining('Connection refused'), findsNothing);
      expect(find.text('Capability Profile'), findsOneWidget);
      expect(find.text('Engineering Style Lens'), findsOneWidget);
    });
  });
}
