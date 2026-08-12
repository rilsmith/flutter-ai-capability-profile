import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart';

Future<void> downloadCsvFile(String csvContent, String filename) async {
  final bytes = utf8.encode(csvContent);
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: 'text/csv'));
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = filename;
  document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}
