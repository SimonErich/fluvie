import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// Platform-specific imports
import 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart'
    as platform;

/// Platform-agnostic file save utility.
///
/// Saves files to user-accessible locations using platform-appropriate methods:
/// - **Desktop** (Linux/macOS/Windows): Copies to Downloads folder
/// - **Mobile** (iOS/Android): Uses platform share sheet
/// - **Web**: Triggers browser download
///
/// Example:
/// ```dart
/// // Save a rendered video
/// final videoPath = await VideoExporter(myVideo).render();
/// await FileSaver.save(videoPath, suggestedName: 'my_video.mp4');
///
/// // Save bytes directly (useful for web)
/// await FileSaver.saveBytes(videoBytes, 'my_video.mp4');
/// ```
class FileSaver {
  FileSaver._();

  /// Saves a file to a user-accessible location.
  ///
  /// [filePath] is the path to the source file to save.
  /// [suggestedName] is an optional suggested file name for the saved file.
  ///
  /// On desktop, copies to the Downloads folder.
  /// On mobile, presents the platform share sheet.
  /// On web, triggers a browser download.
  ///
  /// Throws [FileSystemException] if the operation fails.
  static Future<void> save(String filePath, {String? suggestedName}) async {
    await platform.saveFile(filePath, suggestedName: suggestedName);
  }

  /// Saves bytes directly to a user-accessible location.
  ///
  /// [bytes] is the file content to save.
  /// [fileName] is the name for the saved file.
  /// [mimeType] is the MIME type of the file (used on web).
  ///
  /// This is particularly useful for web platform where file paths
  /// may not be accessible.
  static Future<void> saveBytes(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'video/mp4',
  }) async {
    await platform.saveBytes(bytes, fileName, mimeType: mimeType);
  }

  /// Returns the default downloads directory path.
  ///
  /// Returns `null` on platforms where downloads directory is not applicable
  /// (e.g., web).
  static Future<String?> getDownloadsPath() async {
    if (kIsWeb) return null;
    return platform.getDownloadsPath();
  }
}
