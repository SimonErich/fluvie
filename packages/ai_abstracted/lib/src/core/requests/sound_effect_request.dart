import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// A request to generate a short non-musical sound effect.
@immutable
final class SoundEffectRequest extends GenerationRequest {
  /// Creates a [SoundEffectRequest].
  const SoundEffectRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.seconds,
    this.format = 'mp3',
    this.promptInfluence,
    this.extra = const {},
  });

  /// The desired effect length in seconds, when the provider supports it.
  final double? seconds;

  /// The desired audio container format (defaults to `mp3`).
  final String format;

  /// How strongly the prompt steers the result (0..1), for providers that
  /// expose it.
  final double? promptInfluence;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.soundEffect;
}
