import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a [RepaintBoundary] referenced by [key] as a PNG.
Future<({Uint8List png, Size logicalSize})> captureRepaintBoundary(
  GlobalKey key, {
  double pixelRatio = 2,
}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('PDF capture boundary is not ready.');
  }

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode dashboard snapshot.');
    }
    return (
      png: byteData.buffer.asUint8List(),
      logicalSize: boundary.size,
    );
  } finally {
    image.dispose();
  }
}
