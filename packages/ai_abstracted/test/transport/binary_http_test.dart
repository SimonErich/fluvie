import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final uri = Uri.parse('https://example.test/file.bin');
  final payload = Uint8List.fromList([1, 2, 3, 4]);

  group('getBytes', () {
    test('returns the bytes and mime type on 200', () async {
      final client = MockClient((_) async {
        return http.Response.bytes(
          payload,
          200,
          headers: const {'content-type': 'audio/mpeg'},
        );
      });
      final result = await getBytes(client, uri, provider: 'p');
      expect(result.bytes, payload);
      expect(result.mimeType, 'audio/mpeg');
    });

    test('strips parameters from the content-type', () async {
      final client = MockClient((_) async {
        return http.Response.bytes(payload, 200, headers: const {'content-type': 'image/png; q=1'});
      });
      final result = await getBytes(client, uri, provider: 'p');
      expect(result.mimeType, 'image/png');
    });

    test('defaults the mime type when absent', () async {
      final client = MockClient((_) async => http.Response.bytes(payload, 200));
      final result = await getBytes(client, uri, provider: 'p');
      expect(result.mimeType, 'application/octet-stream');
    });

    test('maps non-2xx via the shared mapper', () {
      final client = MockClient((_) async => http.Response('nope', 401));
      expect(
        () => getBytes(client, uri, provider: 'p'),
        throwsA(isA<AiAuthException>()),
      );
    });

    test('wraps a transport throw as AiTransientException', () {
      final client = MockClient((_) async => throw Exception('down'));
      expect(
        () => getBytes(client, uri, provider: 'p'),
        throwsA(isA<AiTransientException>()),
      );
    });

    test('rethrows an AiException from the client unchanged', () {
      final boom = AiRateLimitException('x', provider: 'p');
      final client = MockClient((_) async => throw boom);
      expect(() => getBytes(client, uri, provider: 'p'), throwsA(same(boom)));
    });

    test('uses a status-only message when the error body is empty', () {
      final client = MockClient((_) async => http.Response('', 503));
      expect(
        () => getBytes(client, uri, provider: 'p'),
        throwsA(isA<AiTransientException>().having((e) => e.message, 'message', contains('503'))),
      );
    });
  });

  group('postForBytes', () {
    test('POSTs JSON and returns the raw bytes', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(payload, 200, headers: const {'content-type': 'audio/mpeg'});
      });
      final result = await postForBytes(
        client,
        uri,
        headers: const {'xi-api-key': 'k'},
        body: const {'text': 'hi'},
        provider: 'p',
      );
      expect(result.bytes, payload);
      expect(result.mimeType, 'audio/mpeg');
      expect(seen.headers['content-type'], contains('application/json'));
      expect(jsonDecode(seen.body), {'text': 'hi'});
    });

    test('maps non-2xx via the shared mapper', () {
      final client = MockClient((_) async => http.Response('bad', 422));
      expect(
        () => postForBytes(client, uri, headers: const {}, body: const {}, provider: 'p'),
        throwsA(isA<AiInvalidRequestException>()),
      );
    });

    test('defaults the mime type when absent', () async {
      final client = MockClient((_) async => http.Response.bytes(payload, 200));
      final result = await postForBytes(
        client,
        uri,
        headers: const {},
        body: const {},
        provider: 'p',
      );
      expect(result.mimeType, 'application/octet-stream');
    });
  });
}
