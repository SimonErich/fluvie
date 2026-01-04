import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Gets the downloads directory path - not applicable on web.
Future<String?> getDownloadsPath() async {
  return null;
}

/// Triggers a browser download for the given file.
///
/// On web, this fetches the file content and creates a download link.
Future<void> saveFile(String filePath, {String? suggestedName}) async {
  // On web, filePath is typically a blob URL or server URL
  // We need to fetch it and trigger a download

  final response = await html.HttpRequest.request(
    filePath,
    method: 'GET',
    responseType: 'blob',
  );

  final blob = response.response as html.Blob;
  final fileName = suggestedName ?? _extractFileName(filePath);

  await _triggerDownload(blob, fileName);
}

/// Saves bytes directly by creating a blob and triggering download.
Future<void> saveBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'video/mp4',
}) async {
  final blob = html.Blob([bytes], mimeType);
  await _triggerDownload(blob, fileName);
}

/// Creates a download link and clicks it to trigger the download.
Future<void> _triggerDownload(html.Blob blob, String fileName) async {
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();

  // Clean up after a delay to ensure download starts
  await Future.delayed(const Duration(seconds: 1));
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Extracts a file name from a URL path.
String _extractFileName(String filePath) {
  final uri = Uri.tryParse(filePath);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.last;
  }
  return 'download.mp4';
}
