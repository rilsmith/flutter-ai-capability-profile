// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setBrowserTouchLockEnabled(bool enabled) {
  final body = html.document.body;
  if (body == null) return;

  if (enabled) {
    body.classes.add('chart-radar-dragging');
  } else {
    body.classes.remove('chart-radar-dragging');
  }
}
