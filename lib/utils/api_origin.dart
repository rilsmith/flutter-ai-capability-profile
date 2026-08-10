import 'package:flutter/foundation.dart';

/// Compile-time override for the backend API base URL.
///
/// When set (e.g. `--dart-define=API_BASE_URL=http://localhost:5000`), all
/// authenticated backend calls use this value. When empty, the app falls back
/// to the current page origin on the web, with a special case for the local
/// Flutter web dev server (port 3100) so that calls reach the backend on its
/// declared port (5000). On non-web platforms the default is
/// `http://localhost:5000`.
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

String apiOrigin() {
  if (_apiBaseUrl.isNotEmpty) {
    return _apiBaseUrl;
  }

  if (kIsWeb) {
    final origin = Uri.base.origin;
    // When the Flutter web dev server is used for local development, the web
    // app is served on port 3100 but the backend API is on port 5000. Route
    // API calls to the backend origin in that case.
    if (origin == 'http://localhost:3100') {
      return 'http://localhost:5000';
    }
    return origin;
  }

  return 'http://localhost:5000';
}
