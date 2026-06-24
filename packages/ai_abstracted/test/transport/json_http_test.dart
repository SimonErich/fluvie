import 'dart:convert';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Client _json(int status, Object body, {Map<String, String> headers = const {}}) {
  return MockClient((_) async {
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );
  });
}

void main() {
  final uri = Uri.parse('https://example.test/v1/thing');

  group('postJson', () {
    test('returns the decoded object on 200', () async {
      final client = _json(200, {'ok': true, 'n': 1});
      final result = await postJson(
        client,
        uri,
        headers: const {'x': 'y'},
        body: const {'prompt': 'hi'},
        provider: 'test',
      );
      expect(result['ok'], true);
      expect(result['n'], 1);
    });

    test('accepts a 201 created response', () async {
      final client = _json(201, {'id': 'a'});
      final result = await postJson(client, uri, headers: const {}, body: const {}, provider: 'p');
      expect(result['id'], 'a');
    });

    test('maps 401 to AiAuthException', () {
      final client = _json(401, {'error': 'no'});
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiAuthException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('maps 403 to AiAuthException', () {
      final client = _json(403, {'error': 'no'});
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiAuthException>()),
      );
    });

    test('maps 429 to AiRateLimitException and parses Retry-After', () {
      final client = _json(429, {'error': 'slow'}, headers: const {'retry-after': '12'});
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(
          isA<AiRateLimitException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 12),
          ),
        ),
      );
    });

    test('429 without Retry-After leaves retryAfter null', () {
      final client = _json(429, {'error': 'slow'});
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiRateLimitException>().having((e) => e.retryAfter, 'retryAfter', isNull)),
      );
    });

    test('maps 400 and 422 to AiInvalidRequestException', () {
      expect(
        () => postJson(_json(400, {}), uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiInvalidRequestException>()),
      );
      expect(
        () => postJson(_json(422, {}), uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiInvalidRequestException>()),
      );
    });

    test('maps 5xx to AiTransientException', () {
      expect(
        () => postJson(_json(503, {}), uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiTransientException>()),
      );
    });

    test('maps other 4xx to a bare AiException', () {
      expect(
        () => postJson(_json(418, {}), uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(
          isA<AiException>()
              .having((e) => e is AiInvalidRequestException, 'not invalid', isFalse)
              .having((e) => e.statusCode, 'statusCode', 418),
        ),
      );
    });

    test('maps a non-object JSON body to AiResponseException', () {
      final client = MockClient((_) async => http.Response('[1,2,3]', 200));
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('maps malformed JSON to AiResponseException', () {
      final client = MockClient((_) async => http.Response('not json', 200));
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiResponseException>()),
      );
    });

    test('uses a status-only message when the error body is empty', () {
      final client = MockClient((_) async => http.Response('', 500));
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiTransientException>().having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('wraps a transport throw as AiTransientException', () {
      final client = MockClient((_) async => throw const _FakeSocketException());
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiTransientException>().having((e) => e.cause, 'cause', isNotNull)),
      );
    });

    test('rethrows an AiException from the client unchanged', () {
      final boom = AiAuthException('x', provider: 'p');
      final client = MockClient((_) async => throw boom);
      expect(
        () => postJson(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(same(boom)),
      );
    });
  });

  group('getJson', () {
    test('returns the decoded object on 200', () async {
      final client = _json(200, {'v': 7});
      final result = await getJson(client, uri, headers: const {}, provider: 'p');
      expect(result['v'], 7);
    });

    test('maps non-2xx via the shared mapper', () {
      expect(
        () => getJson(_json(500, {}), uri, headers: const {}, provider: 'p'),
        throwsA(isA<AiTransientException>()),
      );
    });
  });
}

class _FakeSocketException implements Exception {
  const _FakeSocketException();
  @override
  String toString() => 'SocketException: connection failed';
}
