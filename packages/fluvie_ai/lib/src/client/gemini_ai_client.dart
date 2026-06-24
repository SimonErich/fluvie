import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Google Gemini `generateContent` API.
///
/// Delegates to `ai_abstracted`'s [GeminiTextClient]: the system prompt maps to
/// `systemInstruction`, assistant turns to the `model` role, and a JSON schema
/// enables JSON output via `responseMimeType` — robust without committing to a
/// strict response schema.
class GeminiAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] (the full `generateContent` URL) are injectable
  /// for tests; [endpoint] otherwise derives from [model].
  GeminiAiClient({
    required String apiKey,
    this.model = 'gemini-2.5-pro',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _text = GeminiTextClient(
         credentials: ProviderCredentials(apiKey: apiKey),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final GeminiTextClient _text;

  /// The Gemini model id (defaults to `gemini-2.5-pro`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      generateViaTextGenerator(_text, request, model: model);
}
