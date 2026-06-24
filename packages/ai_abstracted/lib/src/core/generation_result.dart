import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// The normalized output of any generation: bytes plus describing metadata.
///
/// The package never writes files; callers persist or cache [bytes] themselves.
@immutable
class GenerationResult {
  /// Creates a [GenerationResult].
  const GenerationResult({
    required this.bytes,
    required this.mimeType,
    required this.kind,
    required this.metadata,
    this.seedUsed,
  });

  /// The raw result bytes (an image, audio, video, or UTF-8 text).
  final Uint8List bytes;

  /// The IANA MIME type of [bytes] (for example `image/png` or `text/plain`).
  final String mimeType;

  /// Which medium [bytes] represents.
  final MediaKind kind;

  /// Normalized metadata describing the result.
  final GenerationMetadata metadata;

  /// The seed the provider actually used, when it reports one back.
  final String? seedUsed;

  /// [bytes] decoded as UTF-8 text, for [MediaKind.text] results.
  String get text => utf8.decode(bytes);
}
