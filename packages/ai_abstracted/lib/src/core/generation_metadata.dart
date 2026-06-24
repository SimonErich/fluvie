import 'package:meta/meta.dart';

/// Normalized metadata describing a generation result.
///
/// Every field except [model] is optional so the same shape fits all six
/// mediums; providers fill in what they report.
@immutable
class GenerationMetadata {
  /// Creates a [GenerationMetadata] for [model].
  const GenerationMetadata({
    required this.model,
    this.durationMs,
    this.hasAudio = false,
    this.width,
    this.height,
    this.providerJobId,
    this.extra = const {},
  });

  /// The provider model id that produced the result.
  final String model;

  /// The media duration in milliseconds, for audio and video results.
  final int? durationMs;

  /// Whether a video result includes an audio track.
  final bool hasAudio;

  /// The pixel width, for image and video results.
  final int? width;

  /// The pixel height, for image and video results.
  final int? height;

  /// The provider-side job or operation id, for long-running jobs.
  final String? providerJobId;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  /// [durationMs] expressed as a [Duration], or null when unknown.
  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);
}
