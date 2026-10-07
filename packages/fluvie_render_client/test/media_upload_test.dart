import 'dart:convert';
import 'dart:typed_data';

import 'package:fluvie_render_client/fluvie_render_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final base = Uri.parse('https://render.test/');
  final bytes = Uint8List.fromList([0, 1, 128, 255]);

  test('uploads exact binary bytes and returns the signed media URL', () async {
    final client = ApiRenderClient(
      baseUrl: base,
      apiToken: 'api-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, base.resolve('v1/media'));
        expect(request.headers['content-type'], 'video/mp4');
        expect(request.headers['authorization'], 'Bearer api-token');
        expect(request.bodyBytes, bytes);
        return http.Response('{"url":"https://render.test/private/cat?token=signed"}', 201);
      }),
    );
    addTearDown(client.close);
    expect(
      await client.uploadMedia(bytes, contentType: 'video/mp4'),
      Uri.parse('https://render.test/private/cat?token=signed'),
    );
  });

  test('encodes project credentials independently from binary data', () async {
    final client = ApiRenderClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters, {'project': 'cats & kittens', 'token': 'a+b/='});
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.bodyBytes, bytes);
        return http.Response('{"url":"https://render.test/cat"}', 201);
      }),
    );
    addTearDown(client.close);
    await client.uploadMedia(
      bytes,
      contentType: 'video/mp4',
      projectId: 'cats & kittens',
      contributionToken: 'a+b/=',
    );
  });

  test('surfaces a rejected upload with its HTTP status and server message', () async {
    final client = ApiRenderClient(
      baseUrl: base,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'Media exceeds the configured upload limit'},
          }),
          413,
        ),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.uploadMedia(bytes, contentType: 'video/mp4'),
      throwsA(
        isA<ApiClientException>()
            .having((error) => error.statusCode, 'status', 413)
            .having((error) => error.message, 'message', contains('upload limit')),
      ),
    );
  });

  test('rejects incomplete project credentials before sending an upload', () async {
    var calls = 0;
    final client = ApiRenderClient(
      baseUrl: base,
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"url":"https://render.test/cat"}', 201);
      }),
    );
    addTearDown(client.close);
    await expectLater(
      client.uploadMedia(bytes, contentType: 'video/mp4', projectId: 'cats'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('projectId and contributionToken'),
        ),
      ),
    );
    await expectLater(
      client.uploadMedia(bytes, contentType: 'video/mp4', contributionToken: 'token'),
      throwsA(isA<ArgumentError>()),
    );
    expect(calls, 0);
  });
}
