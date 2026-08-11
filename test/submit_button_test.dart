import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/widgets/sdlc_tab.dart';

class _TeamNotifierSpy extends TeamNotifier {
  _TeamNotifierSpy() : super.forTesting();

  int fetchCallCount = 0;
  String? lastToken;
  bool? lastForce;

  @override
  Future<void> fetchTeamData(String token, {bool force = false}) async {
    fetchCallCount++;
    lastToken = token;
    lastForce = force;
  }
}

Future<void> _pumpSdlcTab(
  WidgetTester tester, {
  required List<SingleChildWidget> providers,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: const MaterialApp(
        home: Scaffold(body: SDLCTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submitFinder = find.text('Submit');
  await tester.ensureVisible(submitFinder);
  await tester.tap(submitFinder);
  await tester.pumpAndSettle();
}

void main() {
  group('SDLCTab Submit button', () {
    testWidgets('shows Submit button when authenticated', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('hides Submit button when not authenticated', (tester) async {
      final authNotifier = AuthNotifier.forTesting();
      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );

      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('tapping Submit sends the snapshot with Authorization header',
        (tester) async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': '123e4567-e89b-12d3-a456-426614174000',
            'submitted_at': '2024-01-01T00:00:00Z',
          }),
          201,
        );
      });

      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
      );
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider.value(value: dashboardNotifier),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );
      await _tapSubmit(tester);

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/api/submissions');
      expect(capturedRequest!.url.host, 'localhost');
      expect(capturedRequest!.url.port, 5000);
      expect(capturedRequest!.headers['Authorization'], 'Bearer test-token');
      expect(capturedRequest!.headers['Content-Type'], 'application/json');

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['dimensions'], isNotEmpty);
      expect(body['applicationDomains'], isNotEmpty);
      expect(body['maxScore'], equals(5));
    });

    testWidgets('successful submission shows confirmation and refreshes team data',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': '123e4567-e89b-12d3-a456-426614174000',
            'submitted_at': '2024-01-01T00:00:00Z',
          }),
          201,
        );
      });

      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
      );
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider.value(value: dashboardNotifier),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );
      await _tapSubmit(tester);

      expect(find.textContaining('Submitted successfully'), findsOneWidget);
      expect(teamSpy.fetchCallCount, 1);
      expect(teamSpy.lastToken, 'test-token');
      expect(teamSpy.lastForce, isTrue);
    });

    testWidgets('failed submission shows readable error and preserves matrix edits',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
        );
      });

      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
      );
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider.value(value: dashboardNotifier),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );

      // Toggle a capability link before submitting.
      dashboardNotifier.toggleDomainCapability(1, 1);
      await tester.pumpAndSettle();

      await _tapSubmit(tester);

      // The error is shown in both the top banner and the inline matrix card banner.
      expect(find.text('Server error'), findsNWidgets(2));
      expect(find.text('Retry'), findsNWidgets(2));
      expect(teamSpy.fetchCallCount, 0);

      // Verify the matrix still reflects the toggle.
      expect(dashboardNotifier.data.applicationDomains[0].capabilityIds, contains(1));
    });

    testWidgets('matrix modification clears the submit error',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Server error'}),
          500,
        );
      });

      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
      );
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider.value(value: dashboardNotifier),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );

      await _tapSubmit(tester);
      expect(find.text('Server error'), findsNWidgets(2));

      // Toggle a cell after the failed submission; the error should be cleared.
      dashboardNotifier.toggleDomainCapability(1, 1);
      await tester.pumpAndSettle();
      // Allow the persistence timer to fire so it is not pending on teardown.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Server error'), findsNothing);
      expect(dashboardNotifier.submitError, isNull);
    });

    testWidgets('Submit button is disabled while request is in flight',
        (tester) async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': '123e4567-e89b-12d3-a456-426614174000',
            'submitted_at': '2024-01-01T00:00:00Z',
          }),
          201,
        );
      });

      final dashboardNotifier = DashboardNotifier.forTesting(
        httpClient: mockClient,
      );
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );

      final teamSpy = _TeamNotifierSpy();

      await _pumpSdlcTab(
        tester,
        providers: [
          ChangeNotifierProvider.value(value: authNotifier),
          ChangeNotifierProvider.value(value: dashboardNotifier),
          ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
        ],
      );

      final submitFinder = find.text('Submit');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pump();

      expect(find.text('Submitting...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Submit'), findsOneWidget);
      expect(find.textContaining('Submitted successfully'), findsOneWidget);
    });
  });
}
