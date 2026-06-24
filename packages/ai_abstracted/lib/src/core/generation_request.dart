import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// The common base for every typed generation request.
///
/// Subclasses add medium-specific fields (size, duration, voice, and so on) and
/// report their [kind].
@immutable
abstract class GenerationRequest {
  /// Creates a [GenerationRequest] with the shared [prompt], [seed] and [model].
  const GenerationRequest({required this.prompt, this.seed, this.model});

  /// The prompt that drives the generation.
  final String prompt;

  /// An optional seed for reproducible output, when the provider supports it.
  final String? seed;

  /// An optional provider model id override; null uses the client default.
  final String? model;

  /// Which medium this request asks for.
  MediaKind get kind;
}
