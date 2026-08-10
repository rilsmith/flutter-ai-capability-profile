import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_capability_dashboard/providers/auth_notifier.dart';

void main() {
  group('AuthNotifier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('buildLoginUrl uses configured client ID and redirect URI', () async {
      final authNotifier = AuthNotifier();
      await Future.delayed(Duration.zero);

      final url = await authNotifier.buildLoginUrl();

      expect(url, contains('github.com/login/oauth/authorize'));
      expect(url, contains('client_id='));
      expect(url, contains('redirect_uri='));
      expect(url, contains('scope=read:user+user:email'));
      expect(url, contains('state='));
      expect(url, isNot(contains('state=&')));
      expect(url, isNot(contains('state= ')));
    });

    test('buildLoginUrl stores state for later validation', () async {
      final authNotifier = AuthNotifier();
      await Future.delayed(Duration.zero);

      await authNotifier.buildLoginUrl();

      final prefs = await SharedPreferences.getInstance();
      final state = prefs.getString('gh_oauth_state');
      expect(state, isNotNull);
      expect(state, isNotEmpty);
    });

    test('forTesting logout clears user and token', () async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      expect(authNotifier.isLoggedIn, isTrue);

      await authNotifier.logout();

      expect(authNotifier.isLoggedIn, isFalse);
      expect(authNotifier.user, isNull);
      expect(authNotifier.token, isNull);
      expect(authNotifier.error, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gh_token'), isNull);
    });
  });
}
