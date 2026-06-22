import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/api_playground_backend.dart';
import 'package:fluvie_server/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final base = Uri.parse('https://api.test/');

  ApiPlaygroundBackend backend(MockClient mock) => ApiPlaygroundBackend(
    baseUrl: base,
    client: ApiRenderClient(baseUrl: base, httpClient: mock),
    pollInterval: Duration.zero,
  );

  test('validate delegates to the client', () async {
    final mock = MockClient((_) async => http.Response('{"ok":true,"diagnostics":[]}', 200));

    expect((await backend(mock).validate('ok')).ok, isTrue);
  });

  test('render submits a code job and returns the download url', () async {
    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"id":"rnd_1","status":"queued"}', 202);
      }
      return http.Response(
        '{"id":"rnd_1","status":"succeeded",'
        '"video":{"downloadUrl":"https://api.test/v1/files/rnd_1/video.mp4"}}',
        200,
      );
    });

    final result = await backend(mock).render('Video build() => Video(scenes: []);');

    expect(result.exitCode, 0);
    expect(result.downloadUrl, contains('video.mp4'));
  });

  test('render surfaces an api error', () async {
    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"error":{"message":"nope"}}', 500);
      }
      return http.Response('{}', 200);
    });

    final result = await backend(mock).render('x');

    expect(result.exitCode, 1);
    expect(result.stderr, contains('nope'));
  });

  test('an unconfigured backend reports a clear error for both calls', () async {
    final backend = createPlaygroundBackend();

    final validation = await backend.validate('x');
    expect(validation.ok, isFalse);
    expect(validation.diagnostics.single.message, contains('fluvie_server'));

    final render = await backend.render('x');
    expect(render.exitCode, 1);
    expect(render.stderr, contains('fluvie_server'));
  });
}
