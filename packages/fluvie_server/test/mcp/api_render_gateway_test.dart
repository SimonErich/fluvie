import 'dart:convert';

import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/mcp/mcp.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  setUpAll(() => registerFallbackValue(Uri()));

  group('ApiRenderGateway', () {
    test('fetchSpecSchema returns the decoded schema', () async {
      final client = _MockClient();
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('{"type":"object"}', 200));
      final gateway = ApiRenderGateway(baseUrl: Uri.parse('https://api.test'), httpClient: client);

      expect(await gateway.fetchSpecSchema(), {'type': 'object'});
    });

    test('fetchSpecSchema throws on a non-200', () async {
      final client = _MockClient();
      when(
        () => client.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('nope', 503));
      final gateway = ApiRenderGateway(
        baseUrl: Uri.parse('https://api.test'),
        apiToken: 'token',
        httpClient: client,
      );

      await expectLater(gateway.fetchSpecSchema(), throwsStateError);
    });

    test('render submits the request and returns the finished job', () async {
      final client = _MockClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'id': 'j1',
            'status': 'succeeded',
            'video': {'downloadUrl': 'https://api.test/v.mp4'},
          }),
          202,
        ),
      );
      final gateway = ApiRenderGateway(baseUrl: Uri.parse('https://api.test/'), httpClient: client);

      final job = await gateway.render(ApiRenderRequest.key('demo'));

      expect(job.isSucceeded, isTrue);
      expect(job.video!.downloadUrl.toString(), 'https://api.test/v.mp4');
    });

    test('validate posts the code and returns the diagnostics', () async {
      final client = _MockClient();
      when(
        () => client.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'ok': false,
            'diagnostics': [
              {'severity': 'error', 'message': 'boom', 'line': 1, 'column': 1},
            ],
          }),
          200,
        ),
      );
      final gateway = ApiRenderGateway(baseUrl: Uri.parse('https://api.test/'), httpClient: client);

      final result = await gateway.validate('Video build() {}');

      expect(result.ok, isFalse);
      expect(result.diagnostics.single.message, 'boom');
    });

    test('close closes the HTTP client', () {
      final client = _MockClient();
      when(client.close).thenReturn(null);

      ApiRenderGateway(baseUrl: Uri.parse('https://api.test'), httpClient: client).close();

      verify(client.close).called(1);
    });
  });
}
