import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/open_url_stub.dart'
    if (dart.library.js_interop) '../utils/open_url_web.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final oauthConfigured = auth.isOAuthConfigured;
    final isDisabled = auth.loading || !oauthConfigured;

    return Scaffold(
      backgroundColor: DashboardTheme.background,
      body: Center(
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
                const Icon(Icons.insights_rounded,
                    size: 48, color: DashboardTheme.primary),
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
                      fontSize: 14, color: DashboardTheme.muted, height: 1.5),
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
                      style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
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
                          fontSize: 13, color: Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                        borderRadius: BorderRadius.circular(8)),
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
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
