import 'dart:typed_data';

/// The non-web stub of [downloadBytes]: there is no browser to download into, so
/// it fails clearly. The real implementation ships only in a web build.
void downloadBytes(Uint8List bytes, {required String filename, String mimeType = 'video/mp4'}) {
  throw UnsupportedError(
    'downloadBytes is only available in the browser; got a request to download '
    '"$filename".',
  );
}
