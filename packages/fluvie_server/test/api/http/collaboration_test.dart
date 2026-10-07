import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/http/server_app.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../../support/test_deps.dart';

void main() {
  test('real uploads, scoped invitations, contributions and duplicate review', () async {
    final app = buildApp(inMemoryDeps());
    Future<Map<String, dynamic>> post(
      String route,
      Map<String, Object?> body, {
      bool owner = false,
      int status = 200,
    }) async {
      final response = await app(
        Request(
          'POST',
          Uri.parse('http://localhost$route'),
          headers: {'content-type': 'application/json', if (owner) 'authorization': 'Bearer tok'},
          body: jsonEncode(body),
        ),
      );
      expect(response.statusCode, status, reason: route);
      return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    }

    Future<Map<String, Object?>> upload(List<int> bytes, {String? project, String? token}) async {
      final response = await app(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/v1/media',
          ).replace(queryParameters: project == null ? null : {'project': project, 'token': token}),
          headers: {
            'content-type': 'image/png',
            if (project == null) 'authorization': 'Bearer tok',
          },
          body: bytes,
        ),
      );
      expect(response.statusCode, 201);
      final json = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      return {'url': json['url'], 'hash': '${sha256.convert(bytes)}', 'name': 'A moment'};
    }

    final original = await upload([1, 2, 3]);
    final created = await post(
      '/v1/projects',
      {
        'owner': 'Simone',
        'title': 'Our weekend',
        'media': [original],
      },
      owner: true,
      status: 201,
    );
    final id = created['id'] as String;
    final token = created['guestToken'] as String;
    final guest = await app(
      Request('GET', Uri.parse('http://localhost/v1/projects/$id?token=$token')),
    );
    final limited = jsonDecode(await guest.readAsString()) as Map<String, dynamic>;
    expect(limited['owner'], 'Simone');
    expect(limited.containsKey('media'), isFalse);
    expect(limited.containsKey('people'), isFalse);
    final denied = await app(Request('GET', Uri.parse('http://localhost/v1/projects/$id')));
    expect(denied.statusCode, 401);
    final duplicate = await upload([1, 2, 3], project: id, token: token);
    final fresh = await upload([4, 5, 6], project: id, token: token);
    final contributed = await post('/v1/projects/$id/contributions?token=$token', {
      'name': 'Lena',
      'media': [duplicate, fresh],
    });
    expect(contributed, {'added': 1, 'skipped': 1});
    final owner = await app(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/projects/$id'),
        headers: {'authorization': 'Bearer tok'},
      ),
    );
    final project = jsonDecode(await owner.readAsString()) as Map<String, dynamic>;
    expect(project['media'], hasLength(2));
    expect(project['duplicates'], hasLength(1));
    final duplicateId = ((project['duplicates'] as List).first as Map)['id'];
    final reviewed = await post('/v1/projects/$id/duplicates', {
      'id': duplicateId,
      'keepBoth': true,
    }, owner: true);
    expect(reviewed['media'], hasLength(3));
    final again = await post('/v1/projects/$id/duplicates', {
      'id': duplicateId,
      'keepBoth': true,
    }, owner: true);
    expect(again['media'], hasLength(3));
    final guestReview = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/projects/$id/duplicates?token=$token'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'id': duplicateId, 'keepBoth': true}),
      ),
    );
    expect(guestReview.statusCode, 401);
  });
  test('hash mismatch and remote input URLs are rejected', () async {
    final app = buildApp(inMemoryDeps());
    final response = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/projects'),
        headers: {'authorization': 'Bearer tok', 'content-type': 'application/json'},
        body: jsonEncode({
          'owner': 'Owner',
          'title': 'Film',
          'media': [
            {'url': 'https://example.com/photo.jpg', 'hash': 'a' * 64},
          ],
        }),
      ),
    );
    expect(response.statusCode, 400);
  });
}
