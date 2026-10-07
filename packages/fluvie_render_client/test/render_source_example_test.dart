import 'dart:convert';

import 'package:fluvie_render_client/fluvie_render_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../example/render_source.dart';

void main() {
  test('documented source example submits its exact code and returns download facts', () async {
    const code = 'Video build() => Video(scenes: const []);';
    final client = ApiRenderClient(
      baseUrl: Uri.parse('https://render.test/'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'code': code,
          'options': {'quality': 'high', 'poster': '3s'},
        });
        return http.Response(
          jsonEncode({
            'id': 'cat-story',
            'status': 'succeeded',
            'video': {'downloadUrl': 'https://render.test/video?token=signed'},
          }),
          202,
        );
      }),
    );
    addTearDown(client.close);
    final job = await renderSource(client, code);
    expect(job.isSucceeded, isTrue);
    expect(job.video!.downloadUrl.queryParameters['token'], 'signed');
  });
}
