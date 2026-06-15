import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeUri()));

  group('HttpMediaHttpClient.get', () {
    test('returns the body bytes for a 200 response', () async {
      final inner = _MockHttpClient();
      final url = Uri.parse('https://example.com/clip.mp4');
      when(() => inner.get(url)).thenAnswer(
        (_) async => http.Response.bytes(Uint8List.fromList([9, 8, 7]), 200),
      );
      final client = HttpMediaHttpClient(inner);

      expect(await client.get(url), [9, 8, 7]);
    });

    test('a non-200 status throws a FluvieRenderException naming the status', () async {
      final inner = _MockHttpClient();
      final url = Uri.parse('https://example.com/missing.png');
      when(() => inner.get(url)).thenAnswer((_) async => http.Response('nope', 404));
      final client = HttpMediaHttpClient(inner);

      await expectLater(
        () => client.get(url),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('404'))
              .having((e) => e.message, 'message', contains('$url')),
        ),
      );
    });

    test('a transport failure is wrapped in a typed error', () async {
      final inner = _MockHttpClient();
      final url = Uri.parse('https://example.com/x.png');
      when(() => inner.get(url)).thenThrow(const _Boom());
      final client = HttpMediaHttpClient(inner);

      await expectLater(
        () => client.get(url),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('$url')),
        ),
      );
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
