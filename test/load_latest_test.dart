import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/app_shell.dart';
import 'package:ai_capability_dashboard/widgets/sdlc_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _payloadWithLinks() {
  final domains = defaultDashboardData.applicationDomains.map((d) {
    if (d.id == 1) {
      return d.copyWith(
        capabilityIds: const [1],
        involvement: DomainInvolvement.regular,
      );
    }
    return d;
  }).toList();
  return defaultDashboardData.copyWith(applicationDomains: domains).toJson();
}

void main() {
  group('DashboardNotifier.loadLatestSubmission', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });
    testWidgets('updates matrix from returned payload', (tester) async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': '123e4567-e89b-12d3-a456-426614174000',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': _payloadWithLinks(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = notifier.loadLatestSubmission('test-token');
      await tester.pumpAndSettle();
      await future;

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'GET');
      expect(capturedRequest!.url.path, '/api/submissions/me');
      expect(capturedRequest!.headers['Authorization'], 'Bearer test-token');

      final firstDomain = notifier.data.applicationDomains.first;
      expect(firstDomain.capabilityIds, contains(1));
      expect(notifier.loadingLatest, isFalse);
      expect(notifier.latestError, isNull);
      expect(notifier.latestLoaded, isTrue);
    });

    testWidgets('falls back to defaults on 404', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'No submission found'}),
          404,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = notifier.loadLatestSubmission('test-token');
      await tester.pumpAndSettle();
      await future;

      expect(notifier.data.applicationDomains[0].capabilityIds, isEmpty);
      expect(notifier.latestError, isNull);
      expect(notifier.loadingLatest, isFalse);
      expect(notifier.latestLoaded, isTrue);
    });

    testWidgets('sets error and resets to defaults on failure', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = notifier.loadLatestSubmission('test-token');
      await tester.pumpAndSettle();
      await future;

      expect(notifier.latestError, 'Server error');
      expect(notifier.data.applicationDomains[0].capabilityIds, isEmpty);
      expect(notifier.loadingLatest, isFalse);
      // Load is marked as attempted so automatic retry loops do not occur.
      expect(notifier.latestLoaded, isTrue);
    });

    testWidgets('ignores duplicate calls while a request is in flight',
        (tester) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': '1',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': defaultDashboardData.toJson(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future1 = notifier.loadLatestSubmission('test-token');
      final future2 = notifier.loadLatestSubmission('test-token');

      await tester.pumpAndSettle(const Duration(milliseconds: 150));
      await future1;
      await future2;

      expect(requestCount, 1);
      expect(notifier.loadingLatest, isFalse);
      expect(notifier.latestLoaded, isTrue);
    });

    testWidgets('does not retry automatically after failure', (tester) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      await notifier.loadLatestSubmission('test-token');
      await tester.pumpAndSettle();

      await notifier.loadLatestSubmission('test-token');
      await tester.pumpAndSettle();

      expect(requestCount, 1);
      expect(notifier.latestError, 'Server error');
      expect(notifier.latestLoaded, isTrue);
    });

    testWidgets('reports loading while request is in flight', (tester) async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'id': '1', 'submitted_at': '2024-01-01T00:00:00Z', 'payload': _payloadWithLinks()}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final notifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = notifier.loadLatestSubmission('test-token');
      expect(notifier.loadingLatest, isTrue);

      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await future;
      expect(notifier.loadingLatest, isFalse);
    });
  });

  group('SDLCTab latest submission loading', () {
    testWidgets('shows loading spinner while fetching', (tester) async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({'id': '1', 'submitted_at': '2024-01-01T00:00:00Z', 'payload': _payloadWithLinks()}),
          200,
          headers: const {'content-type': 'application/json'},
        );
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
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      // Start the fetch before pumping so the widget sees the loading state.
      unawaited(dashboardNotifier.loadLatestSubmission('test-token'));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your latest submission...'), findsOneWidget);
      expect(find.text('Capability × Domain Links'), findsNothing);

      // Allow the delayed request to complete and the widget to rebuild.
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Capability × Domain Links'), findsOneWidget);
    });

    testWidgets('shows matrix after successful load', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': '1',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': _payloadWithLinks(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
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
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = dashboardNotifier.loadLatestSubmission('test-token');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await future;

      expect(find.text('Loading your latest submission...'), findsNothing);
      expect(find.text('Capability × Domain Links'), findsOneWidget);
      expect(dashboardNotifier.data.applicationDomains[0].capabilityIds, contains(1));
    });

    testWidgets('shows error banner and empty matrix on fetch failure',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
          headers: const {'content-type': 'application/json'},
        );
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
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      final future = dashboardNotifier.loadLatestSubmission('test-token');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await future;

      expect(find.text('Server error'), findsOneWidget);
      expect(find.text('Capability × Domain Links'), findsOneWidget);
      expect(dashboardNotifier.data.applicationDomains[0].capabilityIds, isEmpty);
    });
  });

  group('AppShell latest submission trigger', () {
    testWidgets('calls loadLatestSubmission on startup when authenticated',
        (tester) async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': '1',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': defaultDashboardData.toJson(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
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
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );

      // Allow the post-frame callback to start and complete the async request.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'GET');
      expect(capturedRequest!.url.path, '/api/submissions/me');
      expect(capturedRequest!.headers['Authorization'], 'Bearer test-token');
    });

    testWidgets('triggers loadLatestSubmission only once per token',
        (tester) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'id': '1',
            'submitted_at': '2024-01-01T00:00:00Z',
            'payload': defaultDashboardData.toJson(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
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
      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
        skipApiCalls: false,
      );

      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppShell()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requestCount, 1);
    });
  });
}
