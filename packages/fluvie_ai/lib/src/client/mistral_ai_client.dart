import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:fluvie_ai/src/client/vision_chat_transport.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Mistral chat-completions API.
///
/// Uses `ai_abstracted`'s [MistralTextClient] for text and native image messages
/// for vision requests. Select a vision-capable [model] for image references.
/// Full-schema validation belongs to the author service's repair loop.
final class MistralAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] are injectable for tests.
  MistralAiClient({
    required String apiKey,
    this.model = 'mistral-large-latest',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _httpClient = httpClient,
       _apiKey = apiKey,
       _endpoint = endpoint ?? Uri.parse('https://api.mistral.ai/v1/chat/completions'),
       _text = MistralTextClient(
         credentials: ProviderCredentials(apiKey: apiKey),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final MistralTextClient _text;
  final http.Client? _httpClient;
  final String _apiKey;
  final Uri _endpoint;

  /// The Mistral model id (defaults to `mistral-large-latest`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      request.messages.any((turn) => turn.image != null)
      ? generateVisionChat(
          request,
          model: model,
          endpoint: _endpoint,
          ollama: false,
          httpClient: _httpClient,
          apiKey: _apiKey,
        )
      : generateViaTextGenerator(_text, request, model: model);
}
