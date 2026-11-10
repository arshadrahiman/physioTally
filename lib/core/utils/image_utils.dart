import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  /// Converts a local image file to a Base64 encoded string for database sync.
  /// Safely handles null, empty, or missing files.
  static Future<String?> fileToBase64(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return null;
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('ImageUtils.fileToBase64 error: $e');
      return null;
    }
  }

  /// Decodes a Base64 string from database and writes it to a persistent local cache file.
  /// Returns the absolute path of the saved file for Image.file() and PDF generation.
  static Future<String?> base64ToLocalFile(String? base64Str, String filename) async {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(base64Str.trim());
      if (bytes.isEmpty) return null;

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('ImageUtils.base64ToLocalFile error: $e');
      return null;
    }
  }
}
