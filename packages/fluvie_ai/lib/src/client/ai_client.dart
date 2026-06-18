import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Who authored a message in an AI conversation.
enum AiRole {
  /// Instructions that set the model's behavior.
  system,

  /// Input from the user (the prompt or a refinement request).
  user,

  /// A previous reply from the model (used when feeding errors back).
  assistant,
}

/// An inline image attached to a [AiMessage] for visually grounded edits.
@immutable
class AiImage {
  /// Creates an image from raw encoded [bytes] of the given [mediaType].
  const AiImage({required this.bytes, this.mediaType = 'image/png'});

  /// The raw encoded image bytes (for example a PNG poster frame).
  final Uint8List bytes;

  /// The MIME type of [bytes]; defaults to `image/png`.
  final String mediaType;
}

/// One message in an AI conversation.
@immutable
class AiMessage {
  /// A system message that sets behavior.
  const AiMessage.system(this.text) : role = AiRole.system, image = null;

  /// A user message, optionally carrying an [image].
  const AiMessage.user(this.text, {this.image}) : role = AiRole.user;

  /// An assistant message echoing a previous model reply.
  const AiMessage.assistant(this.text) : role = AiRole.assistant, image = null;

  /// Who authored this message.
  final AiRole role;

  /// The message text.
  final String text;

  /// An optional inline image; `null` for text-only messages.
  final AiImage? image;
}

/// A request to an [AiClient].
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

/// A reply from an [AiClient].
@immutable
class AiResponse {
  /// Creates a response carrying the model's [text] (JSON when a schema was set).
  const AiResponse(this.text);

  /// The model's reply text.
  final String text;
}

/// A provider-agnostic large-language-model client.
///
/// Implementations map an [AiRequest] onto one provider's API (Claude, Gemini,
/// Mistral, Ollama, or a test fake) and return the model's reply. The author
/// service drives the structured-output and repair logic on top of this seam.
abstract interface class AiClient {
  /// Whether this provider enforces [AiRequest.jsonSchema] natively. When
  /// `false`, the schema is still given to the model in the prompt.
  bool get supportsStructuredOutput;

  /// Sends [request] to the provider and returns its reply.
  ///
  /// Throws an [AiClientException] on a transport, auth, or response error.
  Future<AiResponse> generate(AiRequest request);
}

/// Thrown when an [AiClient] call fails: a transport error, an auth failure,
/// or a malformed provider response.
class AiClientException implements Exception {
  /// Creates an exception described by [message].
  AiClientException(this.message);

  /// What went wrong, in one actionable sentence.
  final String message;

  @override
  String toString() => 'AiClientException: $message';
}
