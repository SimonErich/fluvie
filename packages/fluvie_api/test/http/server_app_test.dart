import 'dart:convert';
import 'dart:io';

import 'package:fluvie_api/src/cleanup/default_retention_service.dart';
import 'package:fluvie_api/src/cleanup/retention_service.dart';
import 'package:fluvie_api/src/config/server_config.dart';
import 'package:fluvie_api/src/http/server_app.dart';
import 'package:fluvie_api/src/http/server_dependencies.dart';
import 'package:fluvie_api/src/jobs/in_memory_job_store.dart';
import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';
import 'package:fluvie_api/src/jobs/render_queue.dart';
import 'package:fluvie_api/src/storage/in_memory_file_store.dart';
import 'package:fluvie_api/src/storage/signed_token.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../render/fakes/fake_render_runner.dart';

void main() {
  late InMemoryJobStore jobs;
  late InMemoryFileStore files;
  late List<Directory> workDirs;
  var idSeq = 0;
  final now = DateTime.utc(2026, 6, 20, 10);

  setUp(() {
    jobs = InMemoryJobStore();
    files = InMemoryFileStore(now: now);
    workDirs = [];
    idSeq = 0;
    addTearDown(() {
      for (final dir in workDirs) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  ServerConfig config(Map<String, String> extra) =>
      serverConfigFromEnvironment({'API_TOKEN': 'api', 'CLEANUP_TOKEN': 'clean', ...extra});

  Handler app({
    Map<String, String> env = const {},
    FakeRenderRunner? runner,
    RetentionService? retention,
  }) {
    final cfg = config(env);
    final queue = RenderQueue(
      runner: runner ?? FakeRenderRunner(),
      jobStore: jobs,
      fileStore: files,
      fileTtl: cfg.fileTtl,
      now: () => now,
      newId: () => 'rnd_${idSeq++}',
      createWorkDir: (id) async {
        final dir = Directory.systemTemp.createTempSync('fluvie_api_http_');
        workDirs.add(dir);
        return dir;
      },
    );
    return buildApp(
      ServerDependencies(
        config: cfg,
        queue: queue,
        jobStore: jobs,
        fileStore: files,
        retention: retention ?? DefaultRetentionService(jobs, files),
        signer: DownloadTokenSigner(cfg.downloadSigningKey),
        schemaJson: r'{"$id":"video-spec"}',
        now: () => now,
      ),
    );
  }

  Future<Response> send(
    Handler handler,
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? body,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  const auth = {'authorization': 'Bearer api'};

  Future<RenderJob> waitDone(String id) async {
    for (var i = 0; i < 200; i++) {
      final job = await jobs.get(id);
      if (job != null && job.status != JobStatus.queued && job.status != JobStatus.running) {
        return job;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('job $id never finished');
  }

  group('POST /v1/renders', () {
    test('401 without a token', () async {
      final response = await send(app(), 'POST', '/v1/renders', body: {'key': 'demo'});
      expect(response.statusCode, 401);
    });

    test('202 with a valid key body, returning a queued job and Location', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'key': 'demo'},
      );
      expect(response.statusCode, 202);
      expect(response.headers['location'], '/v1/renders/rnd_0');
      final json = jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(json['id'], 'rnd_0');
      expect(json['status'], 'queued');
    });

    test('400 on an invalid body', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'key': 'demo', 'spec': <String, Object?>{}},
      );
      expect(response.statusCode, 400);
    });

    test('503 for a prompt render with no AI key configured', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'prompt': 'a promo'},
      );
      expect(response.statusCode, 503);
    });

    test('202 for a prompt render when an AI key is configured', () async {
      final response = await send(
        app(env: const {'ANTHROPIC_API_KEY': 'sk'}),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'prompt': 'a promo'},
      );
      expect(response.statusCode, 202);
    });

    test('503 for an edit render with no AI key', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {
          'edit': {
            'base': {
              'scenes': [<String, Object?>{}],
            },
            'change': 'bluer',
          },
        },
      );
      expect(response.statusCode, 503);
    });

    test('503 honoring the per-provider key (gemini, mistral)', () async {
      for (final provider in ['gemini', 'mistral']) {
        final response = await send(
          app(),
          'POST',
          '/v1/renders',
          headers: auth,
          body: {'prompt': 'a promo', 'provider': provider},
        );
        expect(response.statusCode, 503, reason: provider);
      }
    });

    test('202 for an ollama prompt render (no key needed)', () async {
      final response = await send(
        app(env: const {'FLUVIE_AI_PROVIDER': 'ollama'}),
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'prompt': 'a promo'},
      );
      expect(response.statusCode, 202);
    });
  });

  group('GET /v1/renders/{id}', () {
    test('401 without a token, 404 for unknown', () async {
      final handler = app();
      expect((await send(handler, 'GET', '/v1/renders/x')).statusCode, 401);
      expect((await send(handler, 'GET', '/v1/renders/x', headers: auth)).statusCode, 404);
    });

    test('reports a succeeded job with private download links', () async {
      final handler = app();
      await send(handler, 'POST', '/v1/renders', headers: auth, body: {'key': 'demo'});
      await waitDone('rnd_0');

      final response = await send(handler, 'GET', '/v1/renders/rnd_0', headers: auth);
      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(json['status'], 'succeeded');
      final video = json['video']! as Map<String, Object?>;
      expect(video['downloadUrl'], contains('/v1/files/rnd_0/video'));
      expect(video['downloadUrl'], contains('token='), reason: 'private link is signed');
    });

    test('410 when a succeeded job file has been cleaned up', () async {
      final handler = app();
      await send(handler, 'POST', '/v1/renders', headers: auth, body: {'key': 'demo'});
      final job = await waitDone('rnd_0');
      await files.delete(job.videoKey!);

      final response = await send(handler, 'GET', '/v1/renders/rnd_0', headers: auth);
      expect(response.statusCode, 410);
    });
  });

  group('GET /v1/files/{id}/{kind}', () {
    Future<RenderJob> renderOne(Handler handler, {String visibility = 'private'}) async {
      await send(
        handler,
        'POST',
        '/v1/renders',
        headers: auth,
        body: {'key': 'demo', 'visibility': visibility},
      );
      return waitDone('rnd_0');
    }

    test('streams a private file with a valid token', () async {
      final handler = app();
      final job = await renderOne(handler);
      final token = DownloadTokenSigner(
        config(const {}).downloadSigningKey,
      ).mint(jobId: job.id, kind: 'video', expiresAt: job.expiresAt);

      final response = await send(
        handler,
        'GET',
        '/v1/files/rnd_0/video?token=$token',
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'video/mp4');
      expect(await response.read().expand((c) => c).toList(), [0, 0, 0, 1]);
    });

    test('401 for a private file with no token, 200 via the API bearer', () async {
      final handler = app();
      await renderOne(handler);
      expect((await send(handler, 'GET', '/v1/files/rnd_0/video')).statusCode, 401);
      final viaBearer = await send(handler, 'GET', '/v1/files/rnd_0/video', headers: auth);
      expect(viaBearer.statusCode, 200);
    });

    test('serves a public file with no token', () async {
      final handler = app();
      await renderOne(handler, visibility: 'public');
      final response = await send(handler, 'GET', '/v1/files/rnd_0/video');
      expect(response.statusCode, 200);
    });

    test('404 for an unknown kind or missing file', () async {
      final handler = app();
      await renderOne(handler);
      expect((await send(handler, 'GET', '/v1/files/rnd_0/audio')).statusCode, 404);
      expect((await send(handler, 'GET', '/v1/files/missing/video')).statusCode, 404);
    });
  });

  group('POST /v1/maintenance/cleanup', () {
    test('401 with the wrong token', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/maintenance/cleanup',
        headers: auth, // API token, not the cleanup token
      );
      expect(response.statusCode, 401);
    });

    test('200 with the cleanup token, honoring dryRun', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/maintenance/cleanup',
        headers: const {'authorization': 'Bearer clean'},
        body: {'dryRun': true},
      );
      expect(response.statusCode, 200);
      final json = jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(json['dryRun'], true);
    });

    test('400 when dryRun is not a boolean', () async {
      final response = await send(
        app(),
        'POST',
        '/v1/maintenance/cleanup',
        headers: const {'authorization': 'Bearer clean'},
        body: {'dryRun': 'yes'},
      );
      expect(response.statusCode, 400);
    });

    test('500 when the sweep throws (error middleware)', () async {
      final response = await send(
        app(retention: _ThrowingRetention()),
        'POST',
        '/v1/maintenance/cleanup',
        headers: const {'authorization': 'Bearer clean'},
      );
      expect(response.statusCode, 500);
    });
  });

  group('GET /', () {
    test('serves an open HTML help page pointing to the docs, repo, and API', () async {
      final response = await send(app(), 'GET', '/');
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      final body = await response.readAsString();
      expect(body, contains('/v1/renders'));
      expect(body, contains('docs.fluvie.dev'));
      expect(body, contains('github.com/SimonErich/fluvie'));
    });
  });

  group('open endpoints', () {
    test('schema, healthz, readyz', () async {
      final handler = app();
      final schema = await send(handler, 'GET', '/v1/schema/video-spec');
      expect(schema.statusCode, 200);
      expect(await schema.readAsString(), contains('video-spec'));
      expect((await send(handler, 'GET', '/v1/healthz')).statusCode, 200);
      expect((await send(handler, 'GET', '/v1/readyz')).statusCode, 200);
    });
  });

  group('CORS', () {
    test('preflight returns the allow-origin for a configured origin', () async {
      final handler = app(env: const {'CORS_ALLOW_ORIGINS': 'https://app.test'});
      final response = await send(
        handler,
        'OPTIONS',
        '/v1/renders',
        headers: const {'origin': 'https://app.test'},
      );
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], 'https://app.test');
    });

    test('a normal request from a configured origin gets the allow-origin', () async {
      final handler = app(env: const {'CORS_ALLOW_ORIGINS': 'https://app.test'});
      final response = await send(
        handler,
        'GET',
        '/v1/healthz',
        headers: const {'origin': 'https://app.test'},
      );
      expect(response.headers['access-control-allow-origin'], 'https://app.test');
    });

    test('an unlisted origin gets no allow-origin header', () async {
      final handler = app(env: const {'CORS_ALLOW_ORIGINS': 'https://app.test'});
      final response = await send(
        handler,
        'GET',
        '/v1/healthz',
        headers: const {'origin': 'https://evil.test'},
      );
      expect(response.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('a wildcard origin allows any', () async {
      final handler = app(env: const {'CORS_ALLOW_ORIGINS': '*'});
      final response = await send(
        handler,
        'GET',
        '/v1/healthz',
        headers: const {'origin': 'https://whatever.test'},
      );
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('no CORS headers when origins are not configured', () async {
      final response = await send(app(), 'GET', '/v1/healthz');
      expect(response.headers.containsKey('access-control-allow-origin'), isFalse);
    });
  });
}

/// A retention service that always throws, to exercise the 500 path.
final class _ThrowingRetention implements RetentionService {
  @override
  Future<RetentionReport> sweep({DateTime? now, bool dryRun = false}) async =>
      throw StateError('boom');
}
