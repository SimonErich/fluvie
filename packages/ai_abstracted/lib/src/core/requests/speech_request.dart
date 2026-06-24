import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// A request to synthesize speech from text.
///
/// Here [prompt] is the text to speak, not a description of it.
@immutable
final class SpeechRequest extends GenerationRequest {
  /// Creates a [SpeechRequest]; [prompt] is the text to speak.
  const SpeechRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.voice,
    this.format = 'mp3',
    this.stability,
    this.similarity,
    this.extra = const {},
  });

  /// The voice id to speak with, when the provider supports voice selection.
  final String? voice;

  /// The desired audio container format (defaults to `mp3`).
  final String format;

  /// Voice stability in the range 0..1, for providers that expose it.
  final double? stability;

  /// Voice similarity in the range 0..1, for providers that expose it.
  final double? similarity;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.speech;
}
