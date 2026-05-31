import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void exportDashboardJson(String jsonString) {
  final bytes = utf8.encode(jsonString);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'capability-profile.json')
    ..click();
  html.Url.revokeObjectUrl(url);
}
