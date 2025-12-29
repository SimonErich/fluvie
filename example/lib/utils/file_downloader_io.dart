import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Linux/Desktop implementation: Copies file to Downloads folder
Future<void> downloadFileIO(String filePath) async {
  try {
    final sourceFile = io.File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('File not found: $filePath');
    }

    // Get Downloads directory
    final downloadsDir = await _getDownloadsDirectory();
    final fileName = path.basename(filePath);
    final destinationPath = path.join(downloadsDir.path, fileName);

    // Copy file to Downloads
    await sourceFile.copy(destinationPath);
  } catch (e) {
    throw Exception('Failed to copy file to Downloads: $e');
  }
}

/// Gets the Downloads directory for the current platform
Future<io.Directory> _getDownloadsDirectory() async {
  // Try to get Downloads directory
  // On Linux, this is typically ~/Downloads
  final homeDir = io.Platform.environment['HOME'];
  if (homeDir != null) {
    final downloadsPath = path.join(homeDir, 'Downloads');
    final downloadsDir = io.Directory(downloadsPath);
    if (await downloadsDir.exists()) {
      return downloadsDir;
    }
  }

  // Fallback to documents directory
  return await getApplicationDocumentsDirectory();
}

/// Stub for web download on IO platform
Future<void> downloadFileWeb(String filePath) async {
  throw UnsupportedError('File download via web not supported on IO platform');
}
