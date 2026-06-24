import 'dart:convert';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: '');
Future<void> _noSleep(Duration _) async {}

http.Response _ok(String text) => http.Response(
  jsonEncode({
    'message': {'role': 'assistant', 'content': text},
  }),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  group('OllamaTextClient', () {
    test('posts to the local chat endpoint with no auth header', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('local hi');
      });
      final generator = OllamaTextClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateText(
        const TextRequest(prompt: 'hi'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.text);
      expect(result.mimeType, 'text/plain');
      expect(result.text, 'local hi');
      expect(result.metadata.model, 'llama3.1');
      expect(seen.url.toString(), 'http://localhost:11434/api/chat');
      expect(seen.headers.containsKey('authorization'), isFalse);
      expect(stages, [GenerationStage.running, GenerationStage.done]);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['model'], 'llama3.1');
      expect(body['stream'], false);
      final messages = body['messages']! as List;
      expect(messages, hasLength(1));
      expect((messages.single as Map)['role'], 'user');
      expect((messages.single as Map)['content'], 'hi');
    });

    test('prepends system, includes history, json format and temperature', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('{}');
      });
      final generator = OllamaTextClient(credentials: _creds, httpClient: client);
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
      expect(body['format'], 'json');
      expect((body['options']! as Map)['temperature'], 0.3);
      final messages = body['messages']! as List;
      expect(messages, hasLength(4));
      expect((messages[0] as Map)['role'], 'system');
      expect((messages[1] as Map)['role'], 'user');
      expect((messages[2] as Map)['role'], 'assistant');
      expect((messages[3] as Map)['content'], 'and now?');
    });

    test('derives the endpoint from the credentials base url when set', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('ok');
      });
      final creds = ProviderCredentials(apiKey: '', baseUrl: Uri.parse('http://ollama.test:1234'));
      final generator = OllamaTextClient(credentials: creds, httpClient: client);
      await generator.generateText(const TextRequest(prompt: 'x'));
      expect(seen.url.toString(), 'http://ollama.test:1234/api/chat');
    });

    test('honors an explicit endpoint override over the base url', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _ok('ok');
      });
      final creds = ProviderCredentials(apiKey: '', baseUrl: Uri.parse('http://ignored.test'));
      final generator = OllamaTextClient(
        credentials: creds,
        httpClient: client,
        endpoint: Uri.parse('http://explicit.test:9000/api/chat'),
      );
      await generator.generateText(const TextRequest(prompt: 'x'));
      expect(seen.url.host, 'explicit.test');
      expect(seen.url.port, 9000);
    });

    test('throws AiResponseException when no message content is present', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'message': <String, Object?>{}}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = OllamaTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('maps a 500 to AiTransientException after retries', () {
      final client = MockClient((_) async => http.Response('boom', 500));
      final generator = OllamaTextClient(
        credentials: _creds,
        httpClient: client,
        sleep: _noSleep,
      );
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiTransientException>()),
      );
    });
  });
}
