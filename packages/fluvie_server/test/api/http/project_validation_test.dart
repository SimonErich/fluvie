import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/http/server_app.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../support/test_deps.dart';

void main() {
  test('project creation rejects a non-text owner as a client error', () async {
    final app = buildApp(inMemoryDeps());
    final response = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/projects'),
        headers: const {'authorization': 'Bearer tok', 'content-type': 'application/json'},
        body: jsonEncode({'owner': 7, 'title': 'Weekend', 'media': <Object?>[]}),
      ),
    );

    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'Invalid project details'},
    });
  });

  test('project creation rejects a non-text title as a client error', () async {
    final app = buildApp(inMemoryDeps());
    final response = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/projects'),
        headers: const {'authorization': 'Bearer tok', 'content-type': 'application/json'},
        body: jsonEncode({'owner': 'Simone', 'title': 7, 'media': <Object?>[]}),
      ),
    );

    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'Invalid project details'},
    });
  });

  test('relative media URLs are rejected without an internal error', () async {
    final app = buildApp(inMemoryDeps());
    final response = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/projects'),
        headers: const {'authorization': 'Bearer tok', 'content-type': 'application/json'},
        body: jsonEncode({
          'owner': 'Simone',
          'title': 'Weekend',
          'media': [
            {'url': '/v1/media/${'a' * 48}', 'hash': 'a' * 64},
          ],
        }),
      ),
    );

    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'Media must be uploaded to this server'},
    });
  });

  test('relative poster URLs are rejected without an internal error', () async {
    final projects = _Projects();
    final photo = await projects.upload([1, 2, 3]);
    final response = await projects.post('/v1/projects', {
      'owner': 'Simone',
      'title': 'Weekend',
      'media': [
        {...photo, 'poster': '/v1/media/${'a' * 48}'},
      ],
    });

    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'Invalid poster'},
    });
  });

  test('a contribution cannot exceed the 400-photo album limit', () async {
    final projects = _Projects();
    final project = await projects.albumWith(399);
    final response = await projects.contribute(project, [
      await projects.upload([10, 20, 30]),
      await projects.upload([40, 50, 60]),
    ]);

    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'This album is full'},
    });
    final unchanged = await projects.read(project['id']! as String);
    expect(unchanged['media'], hasLength(399));
  });

  test('keeping a duplicate cannot exceed capacity and a rejected review can be retried', () async {
    final projects = _Projects();
    final project = await projects.albumWith(400);
    final id = project['id']! as String;
    final full = await projects.read(id);
    final photo = (full['media']! as List<Object?>).first! as Map<String, Object?>;
    final contribution = await projects.contribute(project, [photo]);
    expect(contribution.statusCode, 200);
    expect(jsonDecode(await contribution.readAsString()), {'added': 0, 'skipped': 1});
    final pending = await projects.read(id);
    final duplicate = (pending['duplicates']! as List<Object?>).single! as Map<String, Object?>;

    final response = await projects.post('/v1/projects/$id/duplicates', {
      'id': duplicate['id'],
      'keepBoth': true,
    });
    expect(response.statusCode, 400);
    expect(jsonDecode(await response.readAsString()), {
      'error': {'code': 'invalid_request', 'message': 'This album is full'},
    });
    final unchanged = await projects.read(id);
    expect(unchanged['media'], hasLength(400));
    expect(unchanged['duplicates'], pending['duplicates']);

    final discarded = await projects.post('/v1/projects/$id/duplicates', {
      'id': duplicate['id'],
      'keepBoth': false,
    });
    expect(discarded.statusCode, 200);
    final reviewed = jsonDecode(await discarded.readAsString()) as Map<String, Object?>;
    expect(reviewed['media'], hasLength(400));
    expect((reviewed['duplicates']! as List<Object?>).single, {
      ...duplicate,
      'reviewed': true,
      'kept': false,
    });
  });

  test('uploaded media grants cannot be reused for a different route', () async {
    final projects = _Projects();
    final photo = await projects.upload([1, 2, 3]);
    final url = Uri.parse(photo['url']! as String);
    final response = await projects.post('/v1/projects', {
      'owner': 'Simone',
      'title': 'Weekend',
      'media': [
        {...photo, 'url': '${url.replace(path: '/v1/media/extra/${url.pathSegments.last}')}'},
      ],
    });

    expect(response.statusCode, 400);
  });

  test('poster grants cannot be reused outside the media endpoint', () async {
    final projects = _Projects();
    final photo = await projects.upload([1, 2, 3]);
    final url = Uri.parse(photo['url']! as String);
    final response = await projects.post('/v1/projects', {
      'owner': 'Simone',
      'title': 'Weekend',
      'media': [
        {...photo, 'poster': '${url.replace(path: '/other/media/${url.pathSegments.last}')}'},
      ],
    });

    expect(response.statusCode, 400);
  });
}

class _Projects {
  final Handler app = buildApp(inMemoryDeps());

  Future<Response> post(String route, Map<String, Object?> body) async => app(
    Request(
      'POST',
      Uri.parse('http://localhost$route'),
      headers: const {'authorization': 'Bearer tok', 'content-type': 'application/json'},
      body: jsonEncode(body),
    ),
  );

  Future<Map<String, Object?>> upload(List<int> bytes) async {
    final response = await app(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/media'),
        headers: const {'authorization': 'Bearer tok', 'content-type': 'image/png'},
        body: bytes,
      ),
    );
    expect(response.statusCode, 201);
    final body = jsonDecode(await response.readAsString()) as Map<String, Object?>;
    return {'url': body['url'], 'hash': '${sha256.convert(bytes)}', 'name': 'A moment'};
  }

  Future<Map<String, Object?>> albumWith(int count) async {
    final created = await post('/v1/projects', {
      'owner': 'Simone',
      'title': 'Weekend',
      'media': <Object?>[],
    });
    expect(created.statusCode, 201);
    final project = jsonDecode(await created.readAsString()) as Map<String, Object?>;
    for (var offset = 0; offset < count; offset += 100) {
      final end = offset + 100 < count ? offset + 100 : count;
      final batch = <Map<String, Object?>>[
        for (var index = offset; index < end; index++) await upload(utf8.encode('photo $index')),
      ];
      final added = await contribute(project, batch);
      expect(added.statusCode, 200);
      expect(jsonDecode(await added.readAsString()), {'added': end - offset, 'skipped': 0});
    }
    return project;
  }

  Future<Response> contribute(Map<String, Object?> project, List<Map<String, Object?>> media) =>
      post('/v1/projects/${project['id']}/contributions?token=${project['guestToken']}', {
        'name': 'Lena',
        'media': media,
      });

  Future<Map<String, Object?>> read(String id) async {
    final response = await app(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/projects/$id'),
        headers: const {'authorization': 'Bearer tok'},
      ),
    );
    expect(response.statusCode, 200);
    return jsonDecode(await response.readAsString()) as Map<String, Object?>;
  }
}
