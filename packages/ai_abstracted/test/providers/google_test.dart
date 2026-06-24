import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'k-123');
Future<void> _noSleep(Duration _) async {}

void main() {
  group('GeminiImageClient', () {
    test('returns the inline base64 image and forwards the api key', () async {
      final png = Uint8List.fromList([1, 2, 3]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {'mimeType': 'image/png', 'data': base64Encode(png)},
                    },
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiImageClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateImage(
        const ImageRequest(prompt: 'a fox', width: 512, height: 512),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.image);
      expect(result.bytes, png);
      expect(result.mimeType, 'image/png');
      expect(result.metadata.width, 512);
      expect(seen.url.queryParameters['key'], 'k-123');
      expect(seen.url.path, contains('gemini-2.5-flash-image'));
      expect(stages, [GenerationStage.running, GenerationStage.done]);
    });

    test('honors an endpoint override', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {
                        'mimeType': 'image/png',
                        'data': base64Encode(const [1]),
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiImageClient(
        credentials: _creds,
        httpClient: client,
        endpoint: Uri.parse('https://proxy.test/v1beta/models/m:generateContent'),
      );
      await generator.generateImage(const ImageRequest(prompt: 'x'));
      expect(seen.url.host, 'proxy.test');
      expect(seen.url.queryParameters['key'], 'k-123');
    });

    test('throws AiResponseException when no image part is present', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'no image here'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiImageClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('maps a 401 to AiAuthException', () {
      final client = MockClient((_) async => http.Response('no', 401));
      final generator = GeminiImageClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiAuthException>()),
      );
    });
  });

  group('GeminiTextClient', () {
    test('returns the completion text as UTF-8 bytes', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'hello world'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiTextClient(credentials: _creds, httpClient: client);
      final stages = <GenerationStage>[];
      final result = await generator.generateText(
        const TextRequest(prompt: 'hi'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.text);
      expect(result.mimeType, 'text/plain');
      expect(result.text, 'hello world');
      expect(stages, [GenerationStage.running, GenerationStage.done]);
    });

    test('throws AiResponseException when no text part is present', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'candidates': <Object?>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiTextClient(credentials: _creds, httpClient: client);
      expect(
        () => generator.generateText(const TextRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('sends a system instruction and temperature when given', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiTextClient(credentials: _creds, httpClient: client);
      await generator.generateText(
        const TextRequest(prompt: 'hi', system: 'be terse', temperature: 0.3),
      );
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['systemInstruction'], isNotNull);
      expect((body['generationConfig']! as Map)['temperature'], 0.3);
    });

    test('keeps the body unchanged for a plain prompt', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiTextClient(credentials: _creds, httpClient: client);
      await generator.generateText(const TextRequest(prompt: 'hi'));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body, {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'hi'},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': 4096},
      });
    });

    test('maps history, an image and a json schema into the body', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{}'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = GeminiTextClient(credentials: _creds, httpClient: client);
      await generator.generateText(
        TextRequest(
          prompt: 'and now?',
          history: const [TextMessage.user('hi'), TextMessage.assistant('hello')],
          image: TextImage(bytes: Uint8List.fromList(const [1, 2, 3])),
          jsonSchema: const {'type': 'object'},
        ),
      );
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      final contents = body['contents']! as List;
      expect(contents, hasLength(3));
      expect((contents[0] as Map)['role'], 'user');
      expect((contents[1] as Map)['role'], 'model');
      final last = contents[2] as Map<String, Object?>;
      expect(last['role'], 'user');
      final parts = last['parts']! as List;
      expect((parts[0] as Map)['text'], 'and now?');
      final inline = (parts[1] as Map)['inlineData']! as Map;
      expect(inline['mimeType'], 'image/png');
      expect(inline['data'], base64Encode(const [1, 2, 3]));
      final config = body['generationConfig']! as Map;
      expect(config['responseMimeType'], 'application/json');
    });

    test('maps a 500 to AiTransientException after retries', () {
      final client = MockClient((_) async => http.Response('boom', 500));
      final generator = GeminiTextClient(
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

  group('VeoVideoClient', () {
    test('starts a job, polls to done, downloads the mp4, sets hasAudio', () async {
      final mp4 = Uint8List.fromList([9, 9, 9, 9]);
      var polls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains(':predictLongRunning')) {
          return http.Response(
            jsonEncode({'name': 'operations/abc'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && url.contains('operations/abc')) {
          polls++;
          if (polls < 2) {
            return http.Response(
              jsonEncode({'name': 'operations/abc', 'done': false}),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'name': 'operations/abc',
              'done': true,
              'response': {
                'generateVideoResponse': {
                  'generatedSamples': [
                    {
                      'video': {'uri': 'https://veo.test/out.mp4'},
                    },
                  ],
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('out.mp4')) {
          return http.Response.bytes(mp4, 200, headers: const {'content-type': 'video/mp4'});
        }
        return http.Response('unexpected', 404);
      });

      final generator = VeoVideoClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      final stages = <GenerationStage>[];
      final result = await generator.generateVideo(
        const VideoRequest(prompt: 'a wave'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.video);
      expect(result.bytes, mp4);
      expect(result.metadata.hasAudio, isTrue);
      expect(stages, contains(GenerationStage.done));
    });

    test('forwards the api key via the x-goog-api-key header', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'name': 'operations/x',
            'done': true,
            'response': {
              'generateVideoResponse': {
                'generatedSamples': [
                  {
                    'video': {
                      'bytesBase64Encoded': base64Encode(const [1, 2]),
                    },
                  },
                ],
              },
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = VeoVideoClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      await generator.generateVideo(const VideoRequest(prompt: 'x'));
      expect(seen.headers['x-goog-api-key'], 'k-123');
    });

    test('throws AiResponseException when no operation name is returned', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'foo': 'bar'}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = VeoVideoClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateVideo(const VideoRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('throws AiResponseException when the finished operation has no sample', () {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'name': 'operations/empty'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'name': 'operations/empty', 'done': true, 'response': <String, Object?>{}}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = VeoVideoClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateVideo(const VideoRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('passes an aspect ratio through to the predict parameters', () async {
      late http.Request submit;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          submit = request;
          return http.Response(
            jsonEncode({'name': 'operations/ar'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'name': 'operations/ar',
            'done': true,
            'response': {
              'generateVideoResponse': {
                'generatedSamples': [
                  {
                    'video': {
                      'bytesBase64Encoded': base64Encode(const [1]),
                    },
                  },
                ],
              },
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = VeoVideoClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      await generator.generateVideo(const VideoRequest(prompt: 'x', aspectRatio: '16:9'));
      final body = jsonDecode(submit.body) as Map<String, Object?>;
      expect((body['parameters']! as Map)['aspectRatio'], '16:9');
    });
  });
}
