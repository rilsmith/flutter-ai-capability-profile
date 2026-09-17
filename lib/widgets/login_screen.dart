import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/api_origin.dart';
import '../utils/impersonation.dart';
import '../utils/open_url_stub.dart'
    if (dart.library.js_interop) '../utils/open_url_web.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.httpClient});

  /// Injectable HTTP client for the LDAP search picker (tests).
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final oauthConfigured = auth.isOAuthConfigured;
    final isDisabled = auth.loading || !oauthConfigured;
    final pickingIdentity = auth.isLoggedIn && auth.impersonationPending;

    return Scaffold(
      backgroundColor: DashboardTheme.background,
      body: Center(
        // Scrollable so the card still works on short viewports now that the
        // impersonation picker adds extra content.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: DashboardTheme.dashboardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 48,
                    color: DashboardTheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'AI Capability Dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: DashboardTheme.heading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to view and manage your\nteam\'s AI capability profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: DashboardTheme.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!oauthConfigured) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'GitHub OAuth is not configured. Set GITHUB_CLIENT_ID and REDIRECT_URI in the environment before building the app.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (pickingIdentity) ...[
                    Text(
                      'Signed in as ${auth.user!.name.isNotEmpty ? auth.user!.name : auth.user!.login}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DashboardTheme.body,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'View data as (test impersonation):',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: DashboardTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ImpersonationPicker(
                      selfUid: auth.user!.email
                          .split('@')
                          .first
                          .split('+')
                          .first,
                      token: auth.token!,
                      httpClient: httpClient,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => auth.confirmImpersonation(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DashboardTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: isDisabled
                          ? null
                          : () async {
                              final url = await auth.buildLoginUrl();
                              openUrl(url);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF24292F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: auth.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.code_rounded, size: 20),
                      label: Text(
                        auth.loading ? 'Signing in…' : 'Sign in with GitHub',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LdapUserOption {
  const _LdapUserOption({required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  String get label => displayName.isNotEmpty ? '$displayName ($uid)' : uid;

  factory _LdapUserOption.fromJson(Map<String, dynamic> json) {
    return _LdapUserOption(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }
}

/// Search-as-you-type dropdown backed by /api/ldap/search. Selecting a user
/// sets the impersonation target; leaving it empty means "view as yourself".
class _ImpersonationPicker extends StatefulWidget {
  const _ImpersonationPicker({
    required this.selfUid,
    required this.token,
    this.httpClient,
  });

  final String selfUid;
  final String token;
  final http.Client? httpClient;

  @override
  State<_ImpersonationPicker> createState() => _ImpersonationPickerState();
}

class _ImpersonationPickerState extends State<_ImpersonationPicker> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final http.Client _httpClient = widget.httpClient ?? http.Client();
  List<_LdapUserOption> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _httpClient.close();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2 || q == widget.selfUid) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final origin = apiOrigin();
      final resp = await _httpClient
          .get(
            Uri.parse('$origin/api/ldap/search?q=${Uri.encodeComponent(q)}'),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() => _results = []);
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = data['results'] as List<dynamic>? ?? [];
      setState(() {
        _results = raw
            .map((e) => _LdapUserOption.fromJson(e as Map<String, dynamic>))
            .where((u) => u.uid.isNotEmpty && u.uid != widget.selfUid)
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = Impersonation.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<_LdapUserOption>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (option) => option.label,
          optionsBuilder: (value) async {
            await _search(value.text);
            return _results;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search LDAP by name or uid',
                suffixIcon: _searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (selected != null
                          ? IconButton(
                              tooltip: 'Clear — view as yourself',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                Impersonation.setUid(null);
                                controller.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () {
                          Impersonation.setUid(option.uid);
                          _controller.text = option.label;
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          selected == null ? 'Viewing as yourself' : 'Viewing as $selected',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected == null
                ? DashboardTheme.muted
                : DashboardTheme.primary,
          ),
        ),
      ],
    );
  }
}
