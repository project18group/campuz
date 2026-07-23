import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:open_file/open_file.dart';

/// Icon + colour pairing for a file kind (WhatsApp-style document tiles).
class FileKindVisual {
  final IconData icon;
  final Color color;

  const FileKindVisual(this.icon, this.color);
}

/// PLACEHOLDER open service — wraps the `open_file` plugin and maps file
/// extensions to WhatsApp-like icons and colours.
class FileOpenService {
  const FileOpenService._();

  static const _pdf =
      FileKindVisual(Icons.picture_as_pdf_rounded, Color(0xFFE53935)); // red
  static const _word =
      FileKindVisual(Icons.description_rounded, Color(0xFF1E88E5)); // blue
  static const _powerpoint =
      FileKindVisual(Icons.slideshow_rounded, Color(0xFFFB8C00)); // orange
  static const _zip =
      FileKindVisual(Icons.folder_zip_rounded, Color(0xFF8E24AA)); // purple
  static const _image = FileKindVisual(Icons.image_rounded, AppColors.success);
  static const _generic =
      FileKindVisual(Icons.insert_drive_file_rounded, Color(0xFF757575)); // grey

  /// Maps a file extension/type (e.g. 'pdf', 'docx', '.zip') to an
  /// icon + colour pairing.
  static FileKindVisual visualFor(String? extension) {
    switch (extension?.toLowerCase().replaceFirst('.', '')) {
      case 'pdf':
        return _pdf;
      case 'doc':
      case 'docx':
        return _word;
      case 'ppt':
      case 'pptx':
        return _powerpoint;
      case 'zip':
      case 'rar':
      case '7z':
        return _zip;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return _image;
      default:
        return _generic;
    }
  }

  /// Opens a local file with the platform's default app for its type.
  ///
  /// Returns `null` on success, otherwise a user-facing error message.
  static Future<String?> open(String? path) async {
    if (path == null || path.isEmpty) {
      return 'No local path available for this file';
    }
    if (!File(path).existsSync()) {
      return 'File no longer exists locally';
    }
    final result = await OpenFile.open(path);
    if (result.type == ResultType.done) return null;
    return result.message.isNotEmpty ? result.message : 'Could not open file';
  }
}
