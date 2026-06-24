import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/text_image.dart';
import 'package:ai_abstracted/src/core/text_message.dart';
import 'package:meta/meta.dart';

/// A request for a text completion.
@immutable
final class TextRequest extends GenerationRequest {
  /// Creates a [TextRequest].
  const TextRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.system,
    this.history = const [],
    this.image,
    this.maxTokens = 4096,
    this.temperature,
    this.jsonSchema,
    this.extra = const {},
  });

  /// An optional system prompt that frames the model's behavior.
  final String? system;

  /// Prior conversation turns, oldest first; the current user turn is [prompt].
  final List<TextMessage> history;

  /// An optional image attached to the current user turn, for vision models.
  final TextImage? image;

  /// The maximum number of tokens to generate (defaults to 4096).
  final int maxTokens;

  /// The sampling temperature, when the provider supports it.
  final double? temperature;

  /// A JSON schema to constrain the output, for providers that support it.
  final Map<String, Object?>? jsonSchema;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.text;
}
