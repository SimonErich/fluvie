import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'bfl-key');
Future<void> _noSleep(Duration _) async {}

void main() {
  group('FluxImageClient', () {
    test('submits, polls until Ready, fetches the sample, sends x-key', () async {
      final png = Uint8List.fromList([3, 1, 4]);
      late http.Request submit;
      var polls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST' && url.contains('/v1/flux-pro-1.1')) {
          submit = request;
          return http.Response(
            jsonEncode({'id': 'job-1', 'polling_url': 'https://api.bfl.ml/v1/get_result?id=job-1'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('get_result')) {
          polls++;
          if (polls < 2) {
            return http.Response(
              jsonEncode({'status': 'Pending'}),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'Ready',
              'result': {'sample': 'https://img.bfl.ml/out.png'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('out.png')) {
          return http.Response.bytes(png, 200, headers: const {'content-type': 'image/png'});
        }
        return http.Response('unexpected', 404);
      });

      final generator = FluxImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      final stages = <GenerationStage>[];
      final result = await generator.generateImage(
        const ImageRequest(prompt: 'pi'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.image);
      expect(result.bytes, png);
      expect(submit.headers['x-key'], 'bfl-key');
      expect(stages, contains(GenerationStage.downloading));
      expect(stages.last, GenerationStage.done);
    });

    test('accepts a SUCCESS status as terminal', () async {
      final png = Uint8List.fromList([1]);
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'id': 'j', 'polling_url': 'https://api.bfl.ml/v1/get_result?id=j'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('get_result')) {
          return http.Response(
            jsonEncode({
              'status': 'SUCCESS',
              'result': {'sample': 'https://img.bfl.ml/o.png'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(png, 200, headers: const {'content-type': 'image/png'});
      });
      final generator = FluxImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      final result = await generator.generateImage(const ImageRequest(prompt: 'x'));
      expect(result.bytes, png);
    });

    test('throws AiResponseException when submit returns no polling url', () {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({'id': 'j'}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = FluxImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('sends width, height and aspect ratio when provided', () async {
      late http.Request submit;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (request.method == 'POST') {
          submit = request;
          return http.Response(
            jsonEncode({'id': 'j', 'polling_url': 'https://api.bfl.ml/v1/get_result?id=j'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (url.contains('get_result')) {
          return http.Response(
            jsonEncode({
              'status': 'Ready',
              'result': {'sample': 'https://img.bfl.ml/o.png'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(Uint8List(1), 200, headers: const {'content-type': 'image/png'});
      });
      final generator = FluxImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      await generator.generateImage(
        const ImageRequest(prompt: 'x', width: 1024, height: 768, aspectRatio: '4:3'),
      );
      final body = jsonDecode(submit.body) as Map<String, Object?>;
      expect(body['width'], 1024);
      expect(body['height'], 768);
      expect(body['aspect_ratio'], '4:3');
    });

    test('throws AiResponseException when the ready result has no sample', () {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'id': 'j', 'polling_url': 'https://api.bfl.ml/v1/get_result?id=j'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'status': 'Ready', 'result': <String, Object?>{}}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final generator = FluxImageClient(credentials: _creds, httpClient: client, sleep: _noSleep);
      expect(
        () => generator.generateImage(const ImageRequest(prompt: 'x')),
        throwsA(isA<AiResponseException>()),
      );
    });
  });
}
