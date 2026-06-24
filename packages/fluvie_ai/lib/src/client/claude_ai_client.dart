import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Anthropic Messages API (Claude).
///
/// Delegates to `ai_abstracted`'s [ClaudeTextClient]: the system prompt goes in
/// the top-level `system` field and the rest of the conversation becomes
/// `user`/`assistant` turns. The schema is delivered in the prompt (not as
/// native structured output), so the author service's repair loop handles
/// validation — robust across every model.
class ClaudeAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] are injectable for tests.
  ClaudeAiClient({
    required String apiKey,
    this.model = 'claude-opus-4-8',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _text = ClaudeTextClient(
         credentials: ProviderCredentials(apiKey: apiKey),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final ClaudeTextClient _text;

  /// The Claude model id (defaults to `claude-opus-4-8`).
  final String model;

  @override
  bool get supportsStructuredOutput => false;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      generateViaTextGenerator(_text, request, model: model);
}
