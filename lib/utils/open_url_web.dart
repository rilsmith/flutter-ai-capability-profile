import 'package:web/web.dart' as web;

// Navigates in the same tab so the OAuth redirect flow works correctly
Future<void> openUrl(String url) async {
  web.window.location.assign(url);
}
