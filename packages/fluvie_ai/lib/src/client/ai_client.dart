import 'package:fluvie_ai/src/client/ai_client_exception.dart';
import 'package:fluvie_ai/src/client/ai_request.dart';
import 'package:fluvie_ai/src/client/ai_response.dart';

export 'package:fluvie_ai/src/client/ai_client_exception.dart' show AiClientException;
export 'package:fluvie_ai/src/client/ai_image.dart' show AiImage;
export 'package:fluvie_ai/src/client/ai_message.dart' show AiMessage;
export 'package:fluvie_ai/src/client/ai_request.dart' show AiRequest;
export 'package:fluvie_ai/src/client/ai_response.dart' show AiResponse;
export 'package:fluvie_ai/src/client/ai_role.dart' show AiRole;

/// A provider-agnostic large-language-model client.
///
/// Implementations map an [AiRequest] onto one provider's API (Claude, Gemini,
/// Mistral, Ollama, or a test fake) and return the model's reply. The author
/// service drives the structured-output and repair logic on top of this seam.
/// The request/response value types it speaks ([AiRequest], [AiResponse],
/// `AiMessage`, `AiImage`, `AiRole`, [AiClientException]) are re-exported here
/// so importing the seam imports its whole signature.
abstract interface class AiClient {
  /// Whether this provider enforces [AiRequest.jsonSchema] natively. When
  /// `false`, the schema is still given to the model in the prompt.
  bool get supportsStructuredOutput;

  /// Sends [request] to the provider and returns its reply.
  ///
  /// Throws an [AiClientException] on a transport, auth, or response error.
  Future<AiResponse> generate(AiRequest request);
}
