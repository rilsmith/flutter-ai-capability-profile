import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/url_utils_stub.dart'
    if (dart.library.js_interop) '../utils/url_utils_web.dart';

class LdapInfo {
  final String uid;
  final String displayName;
  final String manager;
  final String departmentNumber;

  const LdapInfo({
    required this.uid,
    required this.displayName,
    required this.manager,
    required this.departmentNumber,
  });
}

class GitHubUser {
  final String login;
  final String name;
  final String email;
  final String avatarUrl;

  const GitHubUser({
    required this.login,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });
}

class AuthNotifier extends ChangeNotifier {
  static const _clientId    = 'Iv23li9PMJlRJ1KJyIVJ';
  static const _redirectUri = 'http://localhost:5000/auth';
  static const _tokenKey    = 'gh_token';

  GitHubUser? _user;
  LdapInfo?   _ldapInfo;
  bool        _loading = true;
  String?     _error;
  String?     _token;

  GitHubUser? get user      => _user;
  LdapInfo?   get ldapInfo  => _ldapInfo;
  bool        get isLoggedIn => _user != null;
  bool        get loading    => _loading;
  String?     get error      => _error;
  String?     get token      => _token;

  String get loginUrl {
    final state = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://github.com/login/oauth/authorize'
        '?client_id=$_clientId'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&scope=read:user+user:email'
        '&state=$state';
  }

  AuthNotifier() {
    _init().catchError((Object e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    });
  }

  /// Testing-only constructor that bypasses async session restoration.
  AuthNotifier.forTesting({
    GitHubUser? user,
    LdapInfo? ldapInfo,
    String? token,
  })  : _user = user,
        _ldapInfo = ldapInfo,
        _token = token,
        _loading = false;

  Future<void> _init() async {
    // On web, check if the server redirected us back with a token in the URL
    if (kIsWeb) {
      final uri = Uri.base;
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        try { cleanTokenFromUrl(); } catch (_) {}
        _token = token;
        await _loadUser(token);
        _loading = false;
        notifyListeners();
        return;
      }
      final err = uri.queryParameters['error'];
      if (err != null) {
        _error = err;
        _loading = false;
        notifyListeners();
        return;
      }
    }

    // Restore session from storage
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (stored != null) {
      _token = stored;
      await _loadUser(stored);
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadUser(String token) async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final userResp = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: headers,
      );
      if (userResp.statusCode != 200) throw Exception('Token rejected by GitHub');

      final userData = jsonDecode(userResp.body) as Map<String, dynamic>;

      final emailResp = await http.get(
        Uri.parse('https://api.github.com/user/emails'),
        headers: headers,
      );
      final emails  = jsonDecode(emailResp.body) as List<dynamic>;
      final primary = emails.firstWhere(
        (e) => e['primary'] == true,
        orElse: () => emails.first,
      );

      _user = GitHubUser(
        login:     userData['login']      as String? ?? '',
        name:      (userData['name']      as String?) ?? (userData['login'] as String? ?? ''),
        email:     primary['email']       as String? ?? '',
        avatarUrl: userData['avatar_url'] as String? ?? '',
      );
      _token = token;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      await _fetchLdapInfo(_user!.email);
    } catch (e) {
      _error = 'Could not authenticate: $e';
    }
  }

  Future<void> _fetchLdapInfo(String email) async {
    final uid = email.split('@').first.split('+').first;
    if (uid.isEmpty) return;
    try {
      // Use a fixed origin so this works regardless of when Uri.base is sampled
      final origin = kIsWeb ? Uri.base.origin : 'http://localhost:5000';
      final uri  = Uri.parse('$origin/api/ldap?uid=${Uri.encodeComponent(uid)}');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['found'] != true) return;
      _ldapInfo = LdapInfo(
        uid:              data['uid']              as String? ?? uid,
        displayName:      data['displayName']      as String? ?? '',
        manager:          data['manager']          as String? ?? '',
        departmentNumber: data['departmentNumber'] as String? ?? '',
      );
    } catch (_) {
      // LDAP lookup is best-effort; don't break login if it fails
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _user     = null;
    _ldapInfo = null;
    _error    = null;
    _token    = null;
    notifyListeners();
  }
}
