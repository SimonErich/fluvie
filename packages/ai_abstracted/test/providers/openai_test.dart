import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'sk-test');
Future<void> _noSleep(Duration _) async {}

void main() {
  group('OpenAiImageClient', () {
    test('decodes a b64_json image and sends a Bearer token', () async {
      final png = Uint8List.fromList([7, 7, 7]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'data': [
              {'b64_json': base64Encode(png)},
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = OpenAiImageClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateImage(
        const ImageRequest(prompt: 'a dog'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.image);
      expect(result.bytes, png);
      expect(seen.headers['authorization'], 'Bearer sk-test');
      expect(seen.url.path, contains('/v1/images/generations'));
      expect(stages, [GenerationStage.running, GenerationStage.done]);
    });

    test('fetches the image when the response carries a url', () async {
      final png = Uint8List.fromList([4, 5, 6]);
      final client = MockClient((request) async {
        if (request.url.path.contains('/v1/images/generations')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'url': 'https://img.test/out.png'},
              ],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(png, 200, headers: const {'content-type': 'image/png'});
      });
      final generator = OpenAiImageClient(
        credentials: _creds,
        httpClient: client,
        sleep: _noSleep,
      );
      final result = await generator.generateImage(const ImageRequest(prompt: 'x'));
      expect(result.bytes, png);
      expect(result.mimeType, 'image/png');
    });

    test('throws AiResponseException when data is empty', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'data': <Object?>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = OpenAiImageClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('maps a 429 to AiRateLimitException', () {
      final client = MockClient((_) async => http.Response('slow', 429));
      final generator = OpenAiImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiRateLimitException>()),
      );
    });

    test('sends a size and organization header when provided', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'b64_json': base64Encode(const [1]),
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      const creds = ProviderCredentials(apiKey: 'sk', organization: 'org-1');
      final generator = OpenAiImageClient(credentials: creds, httpClient: client);
      await generator.generateImage(const ImageRequest(prompt: 'x', width: 1024, height: 1024));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['size'], '1024x1024');
      expect(seen.headers['openai-organization'], 'org-1');
    });

    test('throws AiResponseException when the entry has no bytes or url', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'revised_prompt': 'only this'},
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = OpenAiImageClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });
  });
}
