import 'dart:convert';

import 'package:fluvie_server/src/api/client/api_client_exception.dart';
import 'package:fluvie_server/src/api/client/api_render_client.dart';
import 'package:fluvie_server/src/api/client/api_render_request.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final base = Uri.parse('https://render.test/');

  ApiRenderClient client(MockClient mock, {String? token}) =>
      ApiRenderClient(baseUrl: base, apiToken: token, httpClient: mock);

  test('createRender posts to /v1/renders with auth and parses 202', () async {
    late http.Request seen;
    final mock = MockClient((request) async {
      seen = request;
      return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
    });

    final view = await client(mock, token: 'secret').createRender(ApiRenderRequest.key('demo'));

    expect(view.id, 'rnd_1');
    expect(seen.method, 'POST');
    expect(seen.url, base.resolve('v1/renders'));
    expect(seen.headers['authorization'], 'Bearer secret');
    expect(jsonDecode(seen.body), {'key': 'demo'});
  });

  test('omits the auth header when no token is set', () async {
    late http.Request seen;
    final mock = MockClient((request) async {
      seen = request;
      return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
    });
    await client(mock).createRender(ApiRenderRequest.key('demo'));
    expect(seen.headers.containsKey('authorization'), isFalse);
  });

  test('getJob fetches /v1/renders/{id}', () async {
    final mock = MockClient((request) async {
      expect(request.url, base.resolve('v1/renders/rnd_1'));
      return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'running'}), 200);
    });
    final view = await client(mock).getJob('rnd_1');
    expect(view.status, 'running');
  });

  test('maps a non-2xx response to ApiClientException with the server message', () async {
    final mock = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'Provide exactly one input'},
        }),
        400,
      ),
    );
    await expectLater(
      client(mock).createRender(ApiRenderRequest.key('demo')),
      throwsA(
        isA<ApiClientException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Provide exactly one input'),
      ),
    );
  });

  test('falls back to a generic message for an unparseable error body', () async {
    final mock = MockClient((_) async => http.Response('not json', 500));
    await expectLater(
      client(mock).createRender(ApiRenderRequest.key('demo')),
      throwsA(isA<ApiClientException>().having((e) => e.message, 'message', 'Request failed')),
    );
  });

  test('throws for a malformed success body', () async {
    final mock = MockClient((_) async => http.Response('{not valid', 202));
    await expectLater(
      client(mock).createRender(ApiRenderRequest.key('demo')),
      throwsA(isA<ApiClientException>().having((e) => e.message, 'm', contains('Malformed'))),
    );
  });

  group('renderAndWait', () {
    test('polls until succeeded, reporting each update', () async {
      final statuses = ['queued', 'running', 'succeeded'];
      var call = 0;
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
        }
        final status = statuses[call.clamp(0, statuses.length - 1)];
        call++;
        return http.Response(jsonEncode({'id': 'rnd_1', 'status': status}), 200);
      });
      final updates = <String>[];

      final view = await client(mock).renderAndWait(
        ApiRenderRequest.key('demo'),
        onUpdate: (job) => updates.add(job.status),
        wait: (_) async {},
      );

      expect(view.isSucceeded, isTrue);
      expect(updates, ['queued', 'queued', 'running', 'succeeded']);
    });

    test('throws when the render fails', () async {
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
        }
        return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'failed', 'error': 'boom'}), 200);
      });
      await expectLater(
        client(mock).renderAndWait(ApiRenderRequest.key('demo'), wait: (_) async {}),
        throwsA(isA<ApiClientException>().having((e) => e.message, 'm', 'boom')),
      );
    });

    test('times out when the render never finishes', () async {
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
        }
        return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'running'}), 200);
      });
      await expectLater(
        client(mock).renderAndWait(
          ApiRenderRequest.key('demo'),
          timeout: const Duration(seconds: 2),
          wait: (_) async {},
        ),
        throwsA(isA<ApiClientException>().having((e) => e.message, 'm', contains('Timed out'))),
      );
    });
  });

  test('uses the real wait between polls by default', () async {
    var polls = 0;
    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'queued'}), 202);
      }
      polls++;
      return http.Response(jsonEncode({'id': 'rnd_1', 'status': 'succeeded'}), 200);
    });
    // No `wait:` override exercises the real (tiny) delay path.
    final view = await client(mock).renderAndWait(
      ApiRenderRequest.key('demo'),
      pollInterval: const Duration(milliseconds: 1),
    );
    expect(view.isSucceeded, isTrue);
    expect(polls, 1);
  });

  test('constructs its own http client when none is injected', () {
    ApiRenderClient(baseUrl: base).close();
  });

  test('close closes an injected client', () {
    final mock = MockClient((_) async => http.Response('', 200));
    client(mock).close();
  });
}
