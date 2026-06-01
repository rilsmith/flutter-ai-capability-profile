import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'save_dashboard_pdf.dart';
import 'widget_capture.dart';

const _filename = 'ai-capability-profile.pdf';
const _capturePixelRatio = 1.0;
const _exportLogicalWidth = 1200.0;
const _segmentCount = 4;

/// Progress: 0.0–1.0 and a short status line.
typedef PdfExportProgress = void Function(double progress, String message);

/// Captures dashboard sections, stitches them, and saves a PDF.
Future<void> exportDashboardPdf(
  List<GlobalKey> segmentKeys, {
  PdfExportProgress? onProgress,
}) async {
  if (segmentKeys.length < _segmentCount) {
    throw ArgumentError('Expected $_segmentCount segment keys for PDF export.');
  }

  onProgress?.call(0.02, 'Rendering dashboard…');
  await _warmUpFrames(2);

  final segmentPngs = <Uint8List>[];
  for (var i = 0; i < _segmentCount; i++) {
    final captureStart = 0.05 + (i / _segmentCount) * 0.45;
    onProgress?.call(captureStart, 'Capturing section ${i + 1} of $_segmentCount…');
    await _yieldToUi();

    final captured = await captureRepaintBoundary(
      segmentKeys[i],
      pixelRatio: _capturePixelRatio,
    );
    segmentPngs.add(captured.png);
    await _yieldToUi(delayMs: 12);
  }

  onProgress?.call(0.52, 'Combining sections…');
  await _yieldToUi();

  final stitched = await _stitchPngsVertically(segmentPngs);
  await _yieldToUi();

  onProgress?.call(0.58, 'Building PDF…');
  await _yieldToUi();

  final pdfBytes = kIsWeb
      ? await _pngToPagedPdf(stitched, onProgress: onProgress, progressBase: 0.58)
      : await compute(_buildPagedPdfFromCapture, stitched);

  onProgress?.call(0.98, 'Downloading…');
  await _yieldToUi();
  await saveDashboardPdf(pdfBytes, _filename);
  onProgress?.call(1.0, 'Done');
}

double get dashboardPdfExportWidth => _exportLogicalWidth;

int get dashboardPdfSegmentCount => _segmentCount;

Future<void> _warmUpFrames(int count) async {
  for (var i = 0; i < count; i++) {
    await _yieldToUi(delayMs: 32);
  }
}

Future<void> _yieldToUi({int delayMs = 24}) async {
  await Future<void>.delayed(Duration.zero);
  await SchedulerBinding.instance.endOfFrame;
  if (delayMs > 0) {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }
}

/// Flattens transparency onto white so web captures do not print as black.
img.Image _flattenOnWhite(img.Image source) {
  final flat = img.Image(width: source.width, height: source.height);
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, source);
  return flat;
}

Future<Uint8List> _stitchPngsVertically(List<Uint8List> pngs) async {
  final decoded = <img.Image>[];
  for (final png in pngs) {
    final image = img.decodePng(png);
    if (image == null) {
      throw StateError('Failed to decode a dashboard section snapshot.');
    }
    decoded.add(_flattenOnWhite(image));
    await _yieldToUi(delayMs: 8);
  }

  const gapPx = 20;
  final width = decoded.map((i) => i.width).reduce(math.max);
  final totalHeight = decoded.fold<int>(0, (sum, i) => sum + i.height) +
      gapPx * (decoded.length - 1);
  final stitched = img.Image(width: width, height: totalHeight);
  img.fill(stitched, color: img.ColorRgb8(255, 255, 255));

  var y = 0;
  for (var i = 0; i < decoded.length; i++) {
    if (i > 0) {
      y += gapPx;
    }
    final image = decoded[i];
    img.compositeImage(stitched, image, dstX: 0, dstY: y);
    y += image.height;
    await _yieldToUi(delayMs: 8);
  }

  return Uint8List.fromList(img.encodePng(stitched));
}

Future<Uint8List> _buildPagedPdfFromCapture(Uint8List png) async {
  return _pngToPagedPdf(png);
}

Future<Uint8List> _pngToPagedPdf(
  Uint8List png, {
  PdfExportProgress? onProgress,
  double progressBase = 0.0,
}) async {
  final decoded = img.decodePng(png);
  if (decoded == null) {
    throw StateError('Failed to decode dashboard snapshot.');
  }
  await _yieldToUi();

  final doc = pw.Document();
  const pageFormat = PdfPageFormat.a4;
  final pageWidth = pageFormat.availableWidth;
  final pageHeight = pageFormat.availableHeight;

  final sliceHeightPx = math.max(
    1,
    (pageHeight * decoded.width / pageWidth).round(),
  );
  final pageCount = (decoded.height / sliceHeightPx).ceil().clamp(1, 999);

  for (var page = 0; page < pageCount; page++) {
    final pageProgress =
        progressBase + (0.38 * (page + 1) / pageCount).clamp(0.0, 0.38);
    onProgress?.call(
      pageProgress,
      'Building PDF (page ${page + 1} of $pageCount)…',
    );
    await _yieldToUi(delayMs: 40);

    final y = page * sliceHeightPx;
    if (y >= decoded.height) break;

    final cropHeight = math.min(sliceHeightPx, decoded.height - y);
    final slice = img.copyCrop(
      decoded,
      x: 0,
      y: y,
      width: decoded.width,
      height: cropHeight,
    );
    final sliceBytes = Uint8List.fromList(img.encodeJpg(slice, quality: 90));

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.Image(
            pw.MemoryImage(sliceBytes),
            width: pageWidth,
            fit: pw.BoxFit.fitWidth,
          ),
        ),
      ),
    );
    await _yieldToUi(delayMs: 24);
  }

  return doc.save();
}
