import 'dart:convert';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'sk-mistral');
Future<void> _noSleep(Duration _) async {}

http.Response _ok(String text) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': text},
      },
    ],
  }),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  group('MistralTextClient', () {
    test('posts to chat completions with a Bearer token', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('bonjour');
      });
      final generator = MistralTextClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateText(
        const TextRequest(prompt: 'hi'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.text);
      expect(result.mimeType, 'text/plain');
      expect(result.text, 'bonjour');
      expect(result.metadata.model, 'mistral-large-latest');
      expect(seen.url.toString(), 'https://api.mistral.ai/v1/chat/completions');
      expect(seen.headers['authorization'], 'Bearer sk-mistral');
      expect(stages, [GenerationStage.running, GenerationStage.done]);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['model'], 'mistral-large-latest');
      expect(body['max_tokens'], 4096);
      final messages = body['messages']! as List;
      expect(messages, hasLength(1));
      expect((messages.single as Map)['role'], 'user');
      expect((messages.single as Map)['content'], 'hi');
    });

    test('prepends system, includes history and json mode and temperature', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('{}');
      });
      final generator = MistralTextClient(credentials: _creds, httpClient: client);
      await generator.generateText(
        const TextRequest(
          prompt: 'and now?',
          system: 'be terse',
          history: [TextMessage.user('hi'), TextMessage.assistant('hello')],
          temperature: 0.3,
          jsonSchema: {'type': 'object'},
        ),
      );
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['temperature'], 0.3);
      expect((body['response_format']! as Map)['type'], 'json_object');
      final messages = body['messages']! as List;
      expect(messages, hasLength(4));
      expect((messages[0] as Map)['role'], 'system');
      expect((messages[0] as Map)['content'], 'be terse');
      expect((messages[1] as Map)['role'], 'user');
      expect((messages[2] as Map)['role'], 'assistant');
      expect((messages[3] as Map)['content'], 'and now?');
    });

    test('throws AiResponseException when no content is present', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'choices': <Object?>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = MistralTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('honors an endpoint override', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('ok');
      });
      final generator = MistralTextClient(
        credentials: _creds,
        httpClient: client,
        endpoint: Uri.parse('https://proxy.test/chat'),
      );
      await generator.generateText(const TextRequest(prompt: 'x'));
      expect(seen.url.host, 'proxy.test');
    });

    test('maps a 500 to AiTransientException after retries', () {
      final client = MockClient((_) async => http.Response('boom', 500));
      final generator = MistralTextClient(
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
      final generator = MistralTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiAuthException>()),
      );
    });
  });
}
