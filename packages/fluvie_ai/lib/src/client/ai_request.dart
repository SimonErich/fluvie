import 'package:fluvie_ai/src/client/ai_message.dart';
import 'package:meta/meta.dart';

/// A request to an `AiClient`.
@immutable
class AiRequest {
  /// Creates a request over [messages], optionally constrained to [jsonSchema].
  const AiRequest({
    required this.messages,
    this.jsonSchema,
    this.maxTokens = 8192,
    this.temperature = 0.4,
  });

  /// The conversation so far, oldest first.
  final List<AiMessage> messages;

  /// The JSON Schema the reply must conform to, or `null` for free text.
  final Map<String, Object?>? jsonSchema;

  /// The output token ceiling.
  final int maxTokens;

  /// The sampling temperature.
  final double temperature;
}
