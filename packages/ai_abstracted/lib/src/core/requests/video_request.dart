import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// A request to generate a video clip.
@immutable
final class VideoRequest extends GenerationRequest {
  /// Creates a [VideoRequest].
  const VideoRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.seconds,
    this.withAudio = true,
    this.width,
    this.height,
    this.fps,
    this.aspectRatio,
    this.extra = const {},
  });

  /// The desired clip length in seconds, when the provider supports it.
  final double? seconds;

  /// Whether to request an audio track (defaults to true; honored by Veo 3).
  final bool withAudio;

  /// The desired pixel width, when the provider supports explicit sizing.
  final int? width;

  /// The desired pixel height, when the provider supports explicit sizing.
  final int? height;

  /// The desired frame rate, when the provider supports it.
  final int? fps;

  /// An aspect ratio hint (for example `16:9`), for providers that prefer it.
  final String? aspectRatio;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.video;
}
