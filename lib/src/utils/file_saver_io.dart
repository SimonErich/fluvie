import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// Gets the downloads directory path for desktop platforms.
Future<String?> getDownloadsPath() async {
  if (Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      return path.join(home, 'Downloads');
    }
  } else if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      return path.join(userProfile, 'Downloads');
    }
  }
  return null;
}

/// Saves a file to the downloads folder on desktop platforms.
///
/// On mobile, this would typically use platform channels to trigger
/// a share sheet or file picker.
Future<void> saveFile(String filePath, {String? suggestedName}) async {
  final sourceFile = File(filePath);
  if (!await sourceFile.exists()) {
    throw FileSystemException('Source file not found', filePath);
  }

  final downloadsPath = await getDownloadsPath();
  if (downloadsPath == null) {
    throw FileSystemException('Could not determine downloads directory');
  }

  final downloadsDir = Directory(downloadsPath);
  if (!await downloadsDir.exists()) {
    await downloadsDir.create(recursive: true);
  }

  final fileName = suggestedName ?? path.basename(filePath);
  final destPath = _getUniqueFilePath(downloadsPath, fileName);

  await sourceFile.copy(destPath);
}

/// Saves bytes directly to the downloads folder.
Future<void> saveBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'video/mp4',
}) async {
  final downloadsPath = await getDownloadsPath();
  if (downloadsPath == null) {
    throw FileSystemException('Could not determine downloads directory');
  }

  final downloadsDir = Directory(downloadsPath);
  if (!await downloadsDir.exists()) {
    await downloadsDir.create(recursive: true);
  }

  final destPath = _getUniqueFilePath(downloadsPath, fileName);
  final file = File(destPath);
  await file.writeAsBytes(bytes);
}

/// Gets a unique file path by appending a number if the file already exists.
String _getUniqueFilePath(String directory, String fileName) {
  final baseName = path.basenameWithoutExtension(fileName);
  final extension = path.extension(fileName);

  var destPath = path.join(directory, fileName);
  var counter = 1;

  while (File(destPath).existsSync()) {
    destPath = path.join(directory, '$baseName ($counter)$extension');
    counter++;
  }

  return destPath;
}
