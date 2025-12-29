import 'dart:js_interop';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:web/web.dart' as web;

/// Web implementation: Reads file bytes and triggers browser download
/// Note: On web, we need the file bytes to be passed or accessible via HTTP
Future<void> downloadFileWeb(String filePath) async {
  try {
    // On web, we can't directly access the file system
    // We need to either:
    // 1. Have the file served via HTTP (if it's a URL)
    // 2. Have the bytes passed directly (would require API change)
    // 3. Use IndexedDB or other browser storage

    // Try to fetch via HTTP if it's a URL
    String url = filePath;
    if (!filePath.startsWith('http://') && !filePath.startsWith('https://')) {
      // For local file paths, try to construct a URL
      // This might work if the file is in the web app's served directory
      url = '/${filePath.replaceAll('\\', '/')}';
    }

    Uint8List bytes;
    try {
      // Try to fetch via HTTP using the Fetch API
      final response = await web.window.fetch(url.toJS).toDart;

      if (!response.ok) {
        throw Exception('HTTP ${response.status}');
      }

      final arrayBuffer = await response.arrayBuffer().toDart;
      bytes = arrayBuffer.toDart.asUint8List();
    } catch (e) {
      // If HTTP fetch fails, the file is not accessible via HTTP
      // On web, we can't access local files directly
      throw Exception(
        'File not accessible on web. On web platform, files must be served via HTTP or '
        'the render service needs to return bytes instead of a file path. '
        'Error: $e',
      );
    }

    // Create blob and trigger download
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'video/mp4'),
    );
    final blobUrl = web.URL.createObjectURL(blob);

    // Extract filename from path
    final fileName = p.basename(filePath);

    // Create anchor element and trigger download
    final anchor = web.HTMLAnchorElement()
      ..href = blobUrl
      ..download = fileName;
    anchor.click();

    // Clean up after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      web.URL.revokeObjectURL(blobUrl);
    });
  } catch (e) {
    rethrow;
  }
}

/// Stub for IO download on web platform
Future<void> downloadFileIO(String filePath) async {
  throw UnsupportedError('File download via IO not supported on web platform');
}
