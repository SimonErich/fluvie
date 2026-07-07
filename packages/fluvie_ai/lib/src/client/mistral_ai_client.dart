import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Mistral chat-completions API.
///
/// Delegates to `ai_abstracted`'s [MistralTextClient]: it uses the OpenAI-style
/// message shape and forces valid JSON when a schema is set, leaving full-schema
/// validation to the author service's repair loop.
final class MistralAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] are injectable for tests.
  MistralAiClient({
    required String apiKey,
    this.model = 'mistral-large-latest',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _text = MistralTextClient(
         credentials: ProviderCredentials(apiKey: apiKey),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final MistralTextClient _text;

  /// The Mistral model id (defaults to `mistral-large-latest`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      generateViaTextGenerator(_text, request, model: model);
}
