import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/utils/impersonation.dart';
import 'package:ai_capability_dashboard/widgets/login_screen.dart';

void main() {
  tearDown(() => Impersonation.setUid(null));

  group('Impersonation', () {
    test('apply adds header only when a target is set', () {
      final headers = {'Authorization': 'Bearer t'};
      Impersonation.apply(headers);
      expect(headers.containsKey('X-Act-As-Uid'), isFalse);

      Impersonation.setUid('tonyg');
      Impersonation.apply(headers);
      expect(headers['X-Act-As-Uid'], 'tonyg');
      expect(Impersonation.active, isTrue);
    });

    test('setUid trims and clears on blank input', () {
      Impersonation.setUid('  tonyg  ');
      expect(Impersonation.uid, 'tonyg');
      Impersonation.setUid('   ');
      expect(Impersonation.active, isFalse);
      Impersonation.setUid(null);
      expect(Impersonation.uid, isNull);
    });

    test('apply overwrites any existing act-as header', () {
      Impersonation.setUid('a');
      final headers = {'X-Act-As-Uid': 'b'};
      Impersonation.apply(headers);
      expect(headers['X-Act-As-Uid'], 'a');
    });
  });

  group('LoginScreen impersonation picker', () {
    Widget wrap(AuthNotifier auth) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
          ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );
    }

    testWidgets('shows picker and Continue instead of sign-in when pending',
        (tester) async {
      final auth = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'rilsmith_adobe',
          name: 'Riley Smith',
          email: 'rilsmith@example.com',
          avatarUrl: '',
        ),
        token: 't',
        canImpersonate: true,
        impersonationPending: true,
      );

      await tester.pumpWidget(wrap(auth));

      expect(find.text('View data as (test impersonation):'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Sign in with GitHub'), findsNothing);
      expect(find.text('Viewing as yourself'), findsOneWidget);
    });

    testWidgets('Continue clears the pending gate and proceeds', (tester) async {
      final auth = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'rilsmith_adobe',
          name: 'Riley Smith',
          email: 'rilsmith@example.com',
          avatarUrl: '',
        ),
        token: 't',
        canImpersonate: true,
        impersonationPending: true,
      );

      await tester.pumpWidget(wrap(auth));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(auth.impersonationPending, isFalse);
      expect(Impersonation.active, isFalse);
    });

    testWidgets('searching LDAP sets the impersonation target on selection',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/ldap/search') {
          return http.Response(
            '{"results": [{"uid": "tonyg", "displayName": "Tony G",'
            ' "mail": "tonyg@example.com"}]}',
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final auth = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'rilsmith_adobe',
          name: 'Riley Smith',
          email: 'rilsmith@example.com',
          avatarUrl: '',
        ),
        token: 't',
        canImpersonate: true,
        impersonationPending: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(
              create: (_) => DashboardNotifier.forTesting(),
            ),
            ChangeNotifierProvider(create: (_) => TeamNotifier.forTesting()),
          ],
          child: MaterialApp(home: LoginScreen(httpClient: mockClient)),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'ton');
      // The Autocomplete options fetch is async; flush microtasks and frames.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final option = find.text('Tony G (tonyg)');
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();

      expect(Impersonation.uid, 'tonyg');
      expect(find.text('Viewing as tonyg'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(auth.impersonationPending, isFalse);
      expect(Impersonation.uid, 'tonyg');
    });
  });
}
