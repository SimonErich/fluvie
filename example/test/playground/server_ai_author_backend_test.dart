import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/server_ai_author_backend.dart';
import 'package:fluvie_server/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ServerAiAuthorBackend _backend(http.Client httpClient) => ServerAiAuthorBackend(
  baseUrl: Uri.parse('https://render.example'),
  client: ApiRenderClient(baseUrl: Uri.parse('https://render.example'), httpClient: httpClient),
  pollInterval: const Duration(milliseconds: 1),
  wait: (_) async {},
);

http.Response _json(Map<String, Object?> body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('ServerAiAuthorBackend', () {
    test('returns the printed code as soon as it appears, before the render ends', () async {
      var gets = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return _json({'id': 'j1', 'status': 'running'}, 202);
        }
        gets++;
        // First poll: still authoring, no code yet. Second poll: code is ready
        // while the render is still running — the backend must return now.
        if (gets == 1) return _json({'id': 'j1', 'status': 'running'}, 200);
        return _json({
          'id': 'j1',
          'status': 'running',
          'code': "import 'package:fluvie/fluvie.dart';\n\nVideo build() {}",
        }, 200);
      });

      final result = await _backend(client).author('a glowing title');

      expect(result.code, contains('Video build()'));
      expect(gets, 2);
    });

    test('sends a prompt request to the renders endpoint', () async {
      Map<String, Object?>? sent;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          sent = jsonDecode(request.body) as Map<String, Object?>;
          return _json({'id': 'j', 'status': 'running', 'code': 'Video build() {}'}, 202);
        }
        return _json({'id': 'j', 'status': 'running', 'code': 'Video build() {}'}, 200);
      });

      await _backend(client).author('a title');

      expect(sent!['prompt'], 'a title');
    });

    test('an edit sends the previous authored spec as the base of a surgical edit', () async {
      const firstSpec = {
        'fluvieSpec': 1,
        'scenes': [
          {'duration': '4s'},
        ],
      };
      final bodies = <Map<String, Object?>>[];
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          bodies.add(jsonDecode(request.body) as Map<String, Object?>);
        }
        return _json({
          'id': 'j',
          'status': 'running',
          'code': 'Video build() {}',
          'spec': firstSpec,
        }, 202);
      });
      final backend = _backend(client);

      await backend.author('a serene ocean title'); // fresh: remembers firstSpec
      await backend.author('make it red', currentCode: 'EXISTING CODE'); // edit

      expect(bodies, hasLength(2));
      expect(bodies[0]['prompt'], 'a serene ocean title');
      final edit = bodies[1]['edit']! as Map<String, Object?>;
      expect(edit['change'], 'make it red');
      expect(edit['base'], firstSpec);
    });

    test('a quota error (429) becomes a friendly AiAuthorException', () async {
      final client = MockClient((request) async {
        return _json({
          'error': {'code': 'rate_limited', 'message': 'Free generation limit reached.'},
        }, 429);
      });

      expect(
        () => _backend(client).author('too many'),
        throwsA(
          isA<AiAuthorException>().having(
            (e) => e.message,
            'message',
            contains('free AI generation limit'),
          ),
        ),
      );
    });

    test('an unconfigured server (503) becomes a friendly AiAuthorException', () async {
      final client = MockClient((request) async {
        return _json({
          'error': {'code': 'unavailable', 'message': 'AI rendering is not configured.'},
        }, 503);
      });

      expect(
        () => _backend(client).author('anything'),
        throwsA(
          isA<AiAuthorException>().having((e) => e.message, 'message', contains('not available')),
        ),
      );
    });

    test('a render that finishes without code becomes a friendly AiAuthorException', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') return _json({'id': 'j', 'status': 'running'}, 202);
        return _json({'id': 'j', 'status': 'succeeded'}, 200);
      });

      expect(
        () => _backend(client).author('hi'),
        throwsA(
          isA<AiAuthorException>().having(
            (e) => e.message,
            'message',
            contains('could not be generated'),
          ),
        ),
      );
    });
  });
}
