import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  setUpAll(() => registerFallbackValue(Uri.parse('https://example.com')));

  late _MockClient client;
  setUp(() => client = _MockClient());

  void stub(String body, {int status = 200}) {
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => http.Response(body, status));
  }

  ({Uri uri, Map<String, String> headers, Map<String, Object?> body}) captureSent() {
    final captured = verify(
      () => client.post(
        captureAny(),
        headers: captureAny(named: 'headers'),
        body: captureAny(named: 'body'),
      ),
    ).captured;
    return (
      uri: captured[0]! as Uri,
      headers: (captured[1]! as Map).cast<String, String>(),
      body: jsonDecode(captured[2]! as String) as Map<String, Object?>,
    );
  }

  const request = AiRequest(
    messages: [AiMessage.system('sys'), AiMessage.user('hello')],
  );

  group('ClaudeAiClient', () {
    ClaudeAiClient build() => ClaudeAiClient(
      apiKey: 'k',
      httpClient: client,
      endpoint: Uri.parse('https://api.anthropic.com/v1/messages'),
    );

    test('shapes the request and parses the text block', () async {
      stub(r'{"content":[{"type":"text","text":"{\"ok\":1}"}]}');
      final response = await build().generate(request);
      expect(response.text, '{"ok":1}');
      expect(build().supportsStructuredOutput, isFalse);

      final sent = captureSent();
      expect(sent.headers['x-api-key'], 'k');
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.body['model'], 'claude-opus-4-8');
      expect(sent.body['system'], 'sys');
      expect(sent.body['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('attaches an image as a content block', () async {
      stub('{"content":[{"type":"text","text":"{}"}]}');
      await build().generate(
        AiRequest(
          messages: [
            AiMessage.user('look', image: AiImage(bytes: Uint8List.fromList([1, 2, 3]))),
          ],
        ),
      );
      final message = (captureSent().body['messages']! as List).first as Map<String, Object?>;
      final blocks = message['content']! as List;
      expect(blocks.any((block) => (block! as Map)['type'] == 'image'), isTrue);
    });

    test('throws on a refusal stop reason', () async {
      stub('{"stop_reason":"refusal","content":[]}');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
    });

    test('throws on no text, non-2xx, invalid JSON, and non-object', () async {
      stub('{"content":[]}');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
      stub('boom', status: 500);
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
      stub('not json');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
      stub('[]');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
    });

    test('wraps a transport error', () async {
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(http.ClientException('offline'));
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
    });
  });

  group('GeminiAiClient', () {
    GeminiAiClient build() => GeminiAiClient(
      apiKey: 'k',
      httpClient: client,
      endpoint: Uri.parse('https://gen.example/x'),
    );

    test('shapes the request and parses parts', () async {
      stub(r'{"candidates":[{"content":{"parts":[{"text":"{\"a\":1}"}]}}]}');
      final response = await build().generate(request);
      expect(response.text, '{"a":1}');
      expect(build().supportsStructuredOutput, isTrue);

      final sent = captureSent();
      expect(sent.headers['x-goog-api-key'], 'k');
      expect(sent.body['systemInstruction'], isNotNull);
      expect((sent.body['generationConfig']! as Map)['responseMimeType'], 'application/json');
      expect(sent.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {'text': 'hello'},
          ],
        },
      ]);
    });

    test('throws on empty candidates', () async {
      stub('{"candidates":[]}');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
    });

    test('derives the canonical endpoint from the model when none is given', () async {
      stub('{"candidates":[{"content":{"parts":[{"text":"{}"}]}}]}');
      await GeminiAiClient(apiKey: 'k', httpClient: client).generate(request);
      expect(
        captureSent().uri.toString(),
        contains('models/gemini-2.5-pro:generateContent'),
      );
    });

    test('attaches an image as an inlineData part', () async {
      stub('{"candidates":[{"content":{"parts":[{"text":"{}"}]}}]}');
      await build().generate(
        AiRequest(
          messages: [
            AiMessage.user('look', image: AiImage(bytes: Uint8List.fromList([4, 5]))),
          ],
        ),
      );
      final content = (captureSent().body['contents']! as List).first as Map<String, Object?>;
      final parts = content['parts']! as List;
      expect(parts.any((part) => (part! as Map).containsKey('inlineData')), isTrue);
    });
  });

  group('MistralAiClient', () {
    MistralAiClient build() => MistralAiClient(
      apiKey: 'k',
      httpClient: client,
      endpoint: Uri.parse('https://api.mistral.ai/v1/chat/completions'),
    );

    test('shapes the request and parses the choice', () async {
      stub(r'{"choices":[{"message":{"content":"{\"b\":2}"}}]}');
      final response = await build().generate(request);
      expect(response.text, '{"b":2}');
      expect(build().supportsStructuredOutput, isTrue);

      final sent = captureSent();
      expect(sent.headers['authorization'], 'Bearer k');
      expect((sent.body['response_format']! as Map)['type'], 'json_object');
      expect(sent.body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('throws on empty choices', () async {
      stub('{"choices":[]}');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
    });
  });

  group('OllamaAiClient', () {
    OllamaAiClient build() => OllamaAiClient(
      httpClient: client,
      endpoint: Uri.parse('http://localhost:11434/api/chat'),
    );

    test('shapes the request and parses the message', () async {
      stub(r'{"message":{"content":"{\"c\":3}"}}');
      final response = await build().generate(request);
      expect(response.text, '{"c":3}');
      expect(build().supportsStructuredOutput, isTrue);

      final sent = captureSent();
      expect(sent.body['format'], 'json');
      expect(sent.body['stream'], false);
      expect(sent.body['model'], 'llama3.1');
    });

    test('throws on a missing message', () async {
      stub('{}');
      await expectLater(build().generate(request), throwsA(isA<AiClientException>()));
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
