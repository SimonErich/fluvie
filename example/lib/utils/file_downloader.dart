import 'package:flutter/foundation.dart';

// Conditional imports - each platform file exports both functions
// On web: file_downloader_web.dart (downloadFileWeb works, downloadFileIO throws)
// On Linux/Desktop: file_downloader_io.dart (downloadFileIO works, downloadFileWeb throws)
// Fallback: file_downloader_stub.dart (both throw)
import 'file_downloader_io.dart'
    if (dart.library.html) 'file_downloader_web.dart';

/// Downloads a file to the user's device.
/// On web: Triggers browser download
/// On Linux: Copies file to Downloads folder
Future<void> downloadFile(String filePath) async {
  if (kIsWeb) {
    await downloadFileWeb(filePath);
  } else {
    await downloadFileIO(filePath);
  }
}
