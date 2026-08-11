import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/widgets/user_menu.dart';

void main() {
  group('UserMenu', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });
    testWidgets('is hidden when user is not authenticated', (tester) async {
      final authNotifier = AuthNotifier.forTesting();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<void>), findsNothing);
      expect(find.text('Test User'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('shows name and avatar fallback when no avatar URL', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('shows manager and department in the opened menu', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        ldapInfo: const LdapInfo(
          uid: 'testuser',
          displayName: 'Test User',
          manager: 'jbellows',
          departmentNumber: '12345',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserMenu));
      await tester.pumpAndSettle();

      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('jbellows'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('shows unavailable manager and department when LDAP info is missing', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserMenu));
      await tester.pumpAndSettle();

      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('unavailable'), findsNWidgets(2));
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('shows unavailable only for empty LDAP fields', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        ldapInfo: const LdapInfo(
          uid: 'testuser',
          displayName: 'Test User',
          manager: '',
          departmentNumber: '12345',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserMenu));
      await tester.pumpAndSettle();

      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('unavailable'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('calls logout when Sign out is tapped', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Sign out'));
      await tester.pumpAndSettle();

      expect(authNotifier.isLoggedIn, isFalse);
      expect(authNotifier.user, isNull);
    });

    testWidgets('shows email in the opened menu', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserMenu));
      await tester.pumpAndSettle();

      expect(find.text('testuser@example.com'), findsOneWidget);
    });

    testWidgets('falls back to GitHub login when name is empty', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: '',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authNotifier,
          child: const MaterialApp(
            home: Scaffold(body: UserMenu()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('testuser'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });
  });
}
