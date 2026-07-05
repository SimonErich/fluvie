import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/generative.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _registry = ProviderRegistry();
const _creds = ProviderCredentials(apiKey: 'key-1');

http.Response _json(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200, headers: const {'content-type': 'application/json'});

void main() {
  group('generateFor image', () {
    test('openai: maps prompt and width/height onto the wire, decodes b64_json', () async {
      final png = Uint8List.fromList([7, 7, 7]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _json({
          'data': [
            {'b64_json': base64Encode(png)},
          ],
        });
      });
      const source = GenerativeSource.image(
        providerId: 'openai',
        prompt: 'a dog',
        params: {'width': 512, 'height': 512},
      );
      final stages = <GenerationStage>[];
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.image);
      expect(result.bytes, png);
      expect(result.mimeType, 'image/png');
      expect(seen.method, 'POST');
      expect(seen.url.path, contains('/v1/images/generations'));
      expect(seen.headers['authorization'], 'Bearer key-1');
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['prompt'], 'a dog');
      expect(body['size'], '512x512');
      expect(stages, [GenerationStage.running, GenerationStage.done]);
    });

    test('gemini: sends the prompt as a text part and the api key as a query param', () async {
      final png = Uint8List.fromList([8, 8]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return _json({
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
        });
      });
      const source = GenerativeSource.image(providerId: 'gemini', prompt: 'a cat');
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.bytes, png);
      expect(result.mimeType, 'image/png');
      expect(seen.url.queryParameters['key'], 'key-1');
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      final contents = body['contents']! as List;
      expect((contents.first as Map)['parts'], [
        {'text': 'a cat'},
      ]);
    });

    test('flux: submits with coerced numeric params, polls, downloads the sample', () async {
      final png = Uint8List.fromList([3, 1, 4]);
      late http.Request submit;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains('/v1/flux-pro-1.1')) {
          submit = request;
          return _json({'id': 'job-1', 'polling_url': 'https://api.bfl.ml/v1/get_result?id=job-1'});
        }
        if (url.contains('get_result')) {
          return _json({
            'status': 'Ready',
            'result': {'sample': 'https://img.bfl.ml/out.png'},
          });
        }
        return http.Response.bytes(png, 200, headers: const {'content-type': 'image/png'});
      });
      const source = GenerativeSource.image(
        providerId: 'flux',
        prompt: 'pi',
        params: {'width': 1024, 'height': 768.0, 'aspectRatio': '4:3'},
      );
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.bytes, png);
      expect(result.mimeType, 'image/png');
      expect(submit.headers['x-key'], 'key-1');
      final body = jsonDecode(submit.body) as Map<String, Object?>;
      expect(body['prompt'], 'pi');
      expect(body['width'], 1024);
      expect(body['height'], 768, reason: 'a double param is coerced to the int the wire wants');
      expect(body['aspect_ratio'], '4:3');
    });
  });

  group('generateFor video', () {
    test('veo: starts the operation, maps aspectRatio and withAudio, polls to done', () async {
      final mp4 = Uint8List.fromList([0, 0, 0, 24]);
      late http.Request start;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains(':predictLongRunning')) {
          start = request;
          return _json({'name': 'operations/abc'});
        }
        if (url.contains('operations/abc')) {
          return _json({
            'name': 'operations/abc',
            'done': true,
            'response': {
              'generateVideoResponse': {
                'generatedSamples': [
                  {
                    'video': {'bytesBase64Encoded': base64Encode(mp4)},
                  },
                ],
              },
            },
          });
        }
        return http.Response('unexpected', 404);
      });
      const source = GenerativeSource.video(
        providerId: 'veo',
        prompt: 'a wave',
        params: {'seconds': 6, 'fps': 24, 'aspectRatio': '16:9', 'withAudio': false},
      );
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.kind, MediaKind.video);
      expect(result.bytes, mp4);
      expect(result.mimeType, 'video/mp4');
      expect(result.metadata.hasAudio, isFalse);
      expect(start.headers['x-goog-api-key'], 'key-1');
      final body = jsonDecode(start.body) as Map<String, Object?>;
      expect(body['instances'], [
        {'prompt': 'a wave'},
      ]);
      expect((body['parameters']! as Map)['aspectRatio'], '16:9');
    });
  });

  group('generateFor music', () {
    test('suno: submits prompt and instrumental, polls the task, downloads the track', () async {
      final audio = Uint8List.fromList([5, 5, 5]);
      late http.Request submit;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains('/api/v1/generate')) {
          submit = request;
          return _json({
            'data': {'taskId': 'task-9'},
          });
        }
        if (url.contains('task-9')) {
          return _json({
            'data': {
              'response': {
                'sunoData': [
                  {'audioUrl': 'https://cdn.suno.test/song.mp3'},
                ],
              },
            },
          });
        }
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      const source = GenerativeSource.music(
        providerId: 'suno',
        prompt: 'lofi beats',
        params: {'instrumental': true, 'seconds': 30},
      );
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.kind, MediaKind.music);
      expect(result.bytes, audio);
      expect(result.mimeType, 'audio/mpeg');
      expect(submit.headers['authorization'], 'Bearer key-1');
      final body = jsonDecode(submit.body) as Map<String, Object?>;
      expect(body['prompt'], 'lofi beats');
      expect(body['instrumental'], isTrue);
    });
  });

  group('generateFor speech', () {
    test('elevenlabs: posts the text to the requested voice with the xi-api-key', () async {
      final audio = Uint8List.fromList([9, 9]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      const source = GenerativeSource.speech(
        providerId: 'elevenlabs',
        prompt: 'hello there',
        params: {'voice': 'voice-42'},
      );
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.kind, MediaKind.speech);
      expect(result.bytes, audio);
      expect(result.mimeType, 'audio/mpeg');
      expect(seen.method, 'POST');
      expect(seen.headers['xi-api-key'], 'key-1');
      expect(seen.url.path, contains('voice-42'));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['text'], 'hello there');
    });
  });

  group('generateFor soundEffect', () {
    test('elevenlabs: posts text and duration_seconds to sound-generation', () async {
      final audio = Uint8List.fromList([6, 6]);
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(audio, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      const source = GenerativeSource.soundEffect(
        providerId: 'elevenlabs',
        prompt: 'glass breaking',
        params: {'seconds': 3},
      );
      final result = await generateFor(
        source,
        registry: _registry,
        credentials: _creds,
        httpClient: client,
      );
      expect(result.kind, MediaKind.soundEffect);
      expect(result.bytes, audio);
      expect(seen.url.path, contains('/v1/sound-generation'));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['text'], 'glass breaking');
      expect(body['duration_seconds'], 3.0, reason: 'an int seconds param is coerced to double');
    });
  });

  group('generateFor errors', () {
    test('a provider without the requested capability throws AiInvalidRequestException', () {
      const source = GenerativeSource.video(providerId: 'flux', prompt: 'x');
      expect(
        () => generateFor(source, registry: _registry, credentials: _creds),
        throwsA(
          isA<AiInvalidRequestException>().having(
            (e) => e.message,
            'message',
            contains('does not support video'),
          ),
        ),
      );
    });

    test('an unknown provider string fails before any request is made', () {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('unexpected', 404);
      });
      const source = GenerativeSource.image(providerId: 'nope', prompt: 'x');
      expect(
        () => generateFor(source, registry: _registry, credentials: _creds, httpClient: client),
        throwsA(
          isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('nope')),
        ),
      );
      expect(requests, 0);
    });
  });
}
