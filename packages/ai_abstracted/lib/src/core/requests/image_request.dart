import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// A request to generate a still image.
@immutable
final class ImageRequest extends GenerationRequest {
  /// Creates an [ImageRequest].
  const ImageRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.width,
    this.height,
    this.aspectRatio,
    this.negativePrompt,
    this.extra = const {},
  });

  /// The desired pixel width, when the provider supports explicit sizing.
  final int? width;

  /// The desired pixel height, when the provider supports explicit sizing.
  final int? height;

  /// An aspect ratio hint (for example `16:9`), for providers that prefer it.
  final String? aspectRatio;

  /// Concepts to steer away from, for providers that support negative prompts.
  final String? negativePrompt;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.image;
}
