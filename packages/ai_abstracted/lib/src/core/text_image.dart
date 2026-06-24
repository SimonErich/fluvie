import 'dart:typed_data';

import 'package:meta/meta.dart';

/// An image attached to the current user turn of a text request.
///
/// Only providers with vision input use it; clients that cannot accept an image
/// ignore it. The [bytes] are sent inline (base64) where the provider supports
/// inline image data.
@immutable
final class TextImage {
  /// Creates a [TextImage] from raw [bytes] of the given [mimeType].
  const TextImage({required this.bytes, this.mimeType = 'image/png'});

  /// The raw image bytes.
  final Uint8List bytes;

  /// The IANA MIME type of [bytes] (defaults to `image/png`).
  final String mimeType;
}
