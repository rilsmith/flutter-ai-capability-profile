import 'package:web/web.dart' as web;

void cleanTokenFromUrl() {
  web.window.history.replaceState(null, '', '/');
}
