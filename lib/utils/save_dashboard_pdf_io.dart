import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveDashboardPdf(Uint8List bytes, String filename) async {
  final path = await FilePicker.platform.saveFile(
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: bytes,
  );
  if (path == null) {
    return;
  }
}
