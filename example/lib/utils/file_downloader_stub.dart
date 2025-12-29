/// Stub implementation for platforms that don't support file downloads
Future<void> downloadFileWeb(String filePath) async {
  throw UnsupportedError('File download not supported on this platform');
}

Future<void> downloadFileIO(String filePath) async {
  throw UnsupportedError('File download not supported on this platform');
}
