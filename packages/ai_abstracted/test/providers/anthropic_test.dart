import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'sk-ant');
Future<void> _noSleep(Duration _) async {}

http.Response _ok(String text) => http.Response(
  jsonEncode({
    'content': [
      {'type': 'text', 'text': text},
    ],
  }),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  group('ClaudeTextClient', () {
    test('posts to the messages endpoint with the api-key headers', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('hi there');
      });
      final generator = ClaudeTextClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateText(
        const TextRequest(prompt: 'hi'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.text);
      expect(result.mimeType, 'text/plain');
      expect(result.text, 'hi there');
      expect(result.metadata.model, 'claude-opus-4-8');
      expect(seen.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(seen.headers['x-api-key'], 'sk-ant');
      expect(seen.headers['anthropic-version'], '2023-06-01');
      expect(stages, [GenerationStage.running, GenerationStage.done]);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['model'], 'claude-opus-4-8');
      expect(body['max_tokens'], 4096);
      final messages = body['messages']! as List;
      expect(messages, hasLength(1));
      expect((messages.single as Map)['role'], 'user');
      expect((messages.single as Map)['content'], 'hi');
    });

    test('includes system, history and an image block', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('ok');
      });
      final generator = ClaudeTextClient(credentials: _creds, httpClient: client);
      await generator.generateText(
        TextRequest(
          prompt: 'and now?',
          system: 'be terse',
          history: const [TextMessage.user('hi'), TextMessage.assistant('hello')],
          image: TextImage(bytes: Uint8List.fromList(const [1, 2, 3])),
        ),
      );
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['system'], 'be terse');
      final messages = body['messages']! as List;
      expect(messages, hasLength(3));
      expect((messages[0] as Map)['role'], 'user');
      expect((messages[0] as Map)['content'], 'hi');
      expect((messages[1] as Map)['role'], 'assistant');
      final last = messages[2] as Map<String, Object?>;
      expect(last['role'], 'user');
      final content = last['content']! as List;
      expect((content[0] as Map)['type'], 'text');
      expect((content[0] as Map)['text'], 'and now?');
      final imageBlock = content[1] as Map<String, Object?>;
      expect(imageBlock['type'], 'image');
      final source = imageBlock['source']! as Map<String, Object?>;
      expect(source['type'], 'base64');
      expect(source['media_type'], 'image/png');
      expect(source['data'], base64Encode(const [1, 2, 3]));
    });

    test('throws AiResponseException when Claude declines', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'stop_reason': 'refusal', 'content': <Object?>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = ClaudeTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(
          isA<AiResponseException>().having((e) => e.provider, 'provider', 'claude'),
        ),
      );
    });

    test('throws AiResponseException when no text block is present', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'thinking', 'text': 'hmm'},
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = ClaudeTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('honors an endpoint and model override', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('ok');
      });
      final generator = ClaudeTextClient(
        credentials: _creds,
        httpClient: client,
        endpoint: Uri.parse('https://proxy.test/messages'),
      );
      await generator.generateText(
        const TextRequest(prompt: 'x', model: 'claude-haiku'),
      );
      expect(seen.url.host, 'proxy.test');
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['model'], 'claude-haiku');
    });

    test('maps a 500 to AiTransientException after retries', () {
      final client = MockClient((_) async => http.Response('boom', 500));
      final generator = ClaudeTextClient(
        credentials: _creds,
        httpClient: client,
        sleep: _noSleep,
      );
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiTransientException>()),
      );
    });

    test('maps a 401 to AiAuthException', () {
      final client = MockClient((_) async => http.Response('no', 401));
      final generator = ClaudeTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiAuthException>()),
      );
    });
  });
}
