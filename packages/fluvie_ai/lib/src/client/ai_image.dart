import 'dart:typed_data';

import 'package:meta/meta.dart';

/// An inline image attached to an `AiMessage` for visually grounded edits.
@immutable
final class AiImage {
  /// Creates an image from raw encoded [bytes] of the given [mediaType].
  const AiImage({required this.bytes, this.mediaType = 'image/png'});

  /// The raw encoded image bytes (for example a PNG poster frame).
  final Uint8List bytes;

  /// The MIME type of [bytes]; defaults to `image/png`.
  final String mediaType;
}
