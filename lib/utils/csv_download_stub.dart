import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<void> downloadCsvFile(String csvContent, String filename) async {
  final bytes = utf8.encode(csvContent);
  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Export CSV',
    fileName: filename,
    bytes: bytes,
  );
  if (result == null) {
    throw Exception('Export cancelled');
  }
}