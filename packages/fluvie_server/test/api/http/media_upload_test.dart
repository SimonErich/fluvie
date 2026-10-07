import 'dart:convert';
import 'package:fluvie_server/src/api/http/server_app.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../../support/test_deps.dart';

void main() {
  test('inputs require authorization and signed downloads preserve bytes', () async {
    final deps = inMemoryDeps();
    final app = buildApp(deps);
    final denied = await app(
      Request('POST', Uri.parse('http://localhost/v1/media'), body: [1, 2, 3]),
    );
    expect(denied.statusCode, 401);
    final created = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/media'),
        headers: {
          'authorization': 'Bearer tok',
          'content-type': 'image/png',
          'content-length': '3',
        },
        body: [1, 2, 3],
      ),
    );
    expect(created.statusCode, 201);
    final url = Uri.parse(
      (jsonDecode(await created.readAsString()) as Map<String, dynamic>)['url'] as String,
    );
    final downloaded = await app(Request('GET', url));
    expect(downloaded.statusCode, 200);
    expect(await downloaded.read().expand((part) => part).toList(), [1, 2, 3]);
    final unsigned = await app(Request('GET', url.replace(query: '')));
    expect(unsigned.statusCode, 401);
  });
  test('oversized and unsupported uploads fail before storing input', () async {
    final app = buildApp(inMemoryDeps());
    final big = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/media'),
        headers: {'authorization': 'Bearer tok', 'content-length': '999999999'},
        body: Stream.value([1]),
      ),
    );
    expect(big.statusCode, 413);
    final html = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/media'),
        headers: {'authorization': 'Bearer tok', 'content-type': 'text/html'},
        body: 'hello',
      ),
    );
    expect(html.statusCode, 400);
  });
}
