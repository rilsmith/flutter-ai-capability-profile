import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart';

void exportDashboardJson(String jsonString) {
  final bytes = utf8.encode(jsonString);
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: 'application/json'));
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = 'capability-profile.json';
  document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}
