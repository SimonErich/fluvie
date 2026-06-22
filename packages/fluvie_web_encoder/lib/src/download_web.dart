import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] as [filename] with [mimeType].
///
/// Wraps the bytes in a `Blob`, points a temporary object-URL anchor at it,
/// clicks it, and revokes the URL — the standard browser save flow. The MP4
/// (or GIF/WebM) never leaves the page.
// coverage:ignore-start
void downloadBytes(Uint8List bytes, {required String filename, String mimeType = 'video/mp4'}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}

// coverage:ignore-end
