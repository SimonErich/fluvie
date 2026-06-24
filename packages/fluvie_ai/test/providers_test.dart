import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements http.Client {}

/// A [TextGenerator] that records the request and returns a canned completion.
class _RecordingGenerator implements TextGenerator {
  _RecordingGenerator(this._text);

  final String _text;
  TextRequest? lastRequest;

  @override
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    lastRequest = request;
    return GenerationResult(
      bytes: Uint8List.fromList(utf8.encode(_text)),
      mimeType: 'text/plain',
      kind: MediaKind.text,
      metadata: const GenerationMetadata(model: 'rec'),
    );
  }
}

/// A [TextGenerator] that always throws [_error].
class _ThrowingGenerator implements TextGenerator {
  _ThrowingGenerator(this._error);

  final AiException _error;

  @override
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => throw _error;
}

void main() {
  group('generateViaTextGenerator', () {
    test('maps system, history, prompt, image, and schema fields', () async {
      final generator = _RecordingGenerator('{"ok":1}');
      final request = AiRequest(
        messages: [
          const AiMessage.system('sys one'),
          const AiMessage.system('sys two'),
          const AiMessage.user('first user'),
          const AiMessage.assistant('prior reply'),
          AiMessage.user('look here', image: AiImage(bytes: Uint8List.fromList([1, 2, 3]))),
        ],
        jsonSchema: const {'type': 'object'},
        maxTokens: 1234,
      );

      final response = await generateViaTextGenerator(generator, request, model: 'm-1');

      expect(response.text, '{"ok":1}');
      final sent = generator.lastRequest!;
      expect(sent.system, 'sys one\n\nsys two');
      expect(sent.model, 'm-1');
      expect(sent.maxTokens, 1234);
      expect(sent.jsonSchema, const {'type': 'object'});
      expect(sent.temperature, request.temperature);
      // History is every non-system message except the last.
      expect(sent.history, [
        const TextMessage.user('first user'),
        const TextMessage.assistant('prior reply'),
      ]);
      // The last non-system message is the prompt plus the image.
      expect(sent.prompt, 'look here');
      expect(sent.image, isNotNull);
      expect(sent.image!.bytes, [1, 2, 3]);
      expect(sent.image!.mimeType, 'image/png');
    });

    test('leaves system null when there are no system messages', () async {
      final generator = _RecordingGenerator('out');
      await generateViaTextGenerator(
        generator,
        const AiRequest(messages: [AiMessage.user('only')]),
      );
      final sent = generator.lastRequest!;
      expect(sent.system, isNull);
      expect(sent.history, isEmpty);
      expect(sent.prompt, 'only');
      expect(sent.model, isNull);
    });

    test('wraps an AiException as an AiClientException with the same message', () async {
      final generator = _ThrowingGenerator(
        AiResponseException('the model declined', provider: 'claude'),
      );
      await expectLater(
        generateViaTextGenerator(
          generator,
          const AiRequest(messages: [AiMessage.user('x')]),
        ),
        throwsA(
          isA<AiClientException>().having((e) => e.message, 'message', 'the model declined'),
        ),
      );
    });
  });

  group('client delegation', () {
    late _MockClient client;
    setUpAll(() => registerFallbackValue(Uri.parse('https://example.com')));
    setUp(() => client = _MockClient());

    void stub(String body) {
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(body, 200));
    }

    const request = AiRequest(
      messages: [AiMessage.system('sys'), AiMessage.user('hello')],
    );

    test('ClaudeAiClient delegates to the Claude text client', () async {
      stub(r'{"content":[{"type":"text","text":"{\"ok\":1}"}]}');
      final claude = ClaudeAiClient(
        apiKey: 'k',
        httpClient: client,
        endpoint: Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      expect(claude.supportsStructuredOutput, isFalse);
      final response = await claude.generate(request);
      expect(response.text, '{"ok":1}');
    });

    test('GeminiAiClient delegates to the Gemini text client', () async {
      stub(r'{"candidates":[{"content":{"parts":[{"text":"{\"a\":1}"}]}}]}');
      final gemini = GeminiAiClient(
        apiKey: 'k',
        httpClient: client,
        endpoint: Uri.parse('https://gen.example/x'),
      );
      expect(gemini.supportsStructuredOutput, isTrue);
      final response = await gemini.generate(request);
      expect(response.text, '{"a":1}');
    });

    test('MistralAiClient delegates to the Mistral text client', () async {
      stub(r'{"choices":[{"message":{"content":"{\"b\":2}"}}]}');
      final mistral = MistralAiClient(
        apiKey: 'k',
        httpClient: client,
        endpoint: Uri.parse('https://api.mistral.ai/v1/chat/completions'),
      );
      expect(mistral.supportsStructuredOutput, isTrue);
      final response = await mistral.generate(request);
      expect(response.text, '{"b":2}');
    });

    test('OllamaAiClient delegates to the Ollama text client', () async {
      stub(r'{"message":{"content":"{\"c\":3}"}}');
      final ollama = OllamaAiClient(
        httpClient: client,
        endpoint: Uri.parse('http://localhost:11434/api/chat'),
      );
      expect(ollama.supportsStructuredOutput, isTrue);
      final response = await ollama.generate(request);
      expect(response.text, '{"c":3}');
    });
  });

  group('aiClientFromEnv', () {
    test('builds each provider', () {
      expect(
        aiClientFromEnv(const {'FLUVIE_AI_PROVIDER': 'claude', 'ANTHROPIC_API_KEY': 'k'}),
        isA<ClaudeAiClient>(),
      );
      expect(aiClientFromEnv(const {'ANTHROPIC_API_KEY': 'k'}), isA<ClaudeAiClient>());
      expect(
        aiClientFromEnv(const {'FLUVIE_AI_PROVIDER': 'gemini', 'GEMINI_API_KEY': 'k'}),
        isA<GeminiAiClient>(),
      );
      expect(
        aiClientFromEnv(const {'FLUVIE_AI_PROVIDER': 'mistral', 'MISTRAL_API_KEY': 'k'}),
        isA<MistralAiClient>(),
      );
      expect(aiClientFromEnv(const {'FLUVIE_AI_PROVIDER': 'ollama'}), isA<OllamaAiClient>());
    });

    test('rejects a missing key and an unknown provider', () {
      expect(() => aiClientFromEnv(const {}), throwsA(isA<AiClientException>()));
      expect(
        () => aiClientFromEnv(const {'FLUVIE_AI_PROVIDER': 'cohere'}),
        throwsA(isA<AiClientException>()),
      );
    });
  });
}
