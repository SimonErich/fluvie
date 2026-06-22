import 'dart:async';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/api/cleanup/default_retention_service.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/mcp/local_render_gateway.dart';
import 'package:test/test.dart';

import '../api/render/fakes/fake_render_runner.dart';
import '../api/validate/fake_code_validation_service.dart';

// Turns the event loop (so the background render can progress) without waiting
// the real poll interval.
Future<void> _noWait(Duration _) => Future<void>.delayed(Duration.zero);

void main() {
  late InMemoryJobStore jobs;
  late InMemoryFileStore files;
  late ServerConfig config;
  late List<Directory> workDirs;

  setUp(() {
    jobs = InMemoryJobStore();
    files = InMemoryFileStore();
    config = serverConfigFromEnvironment(const {'API_TOKEN': 'tok', 'CLEANUP_TOKEN': 'cleanup'});
    workDirs = [];
    addTearDown(() {
      for (final dir in workDirs) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  Future<Directory> makeWorkDir(String jobId) async {
    final dir = Directory.systemTemp.createTempSync('fluvie_server_gw_');
    workDirs.add(dir);
    return dir;
  }

  ServerDependencies depsFor(RenderRunner runner, {String schemaJson = '{}'}) {
    final queue = RenderQueue(
      runner: runner,
      jobStore: jobs,
      fileStore: files,
      fileTtl: const Duration(hours: 24),
      newId: () => 'rnd_test_${DateTime.now().microsecondsSinceEpoch}',
      createWorkDir: makeWorkDir,
    );
    return ServerDependencies(
      config: config,
      queue: queue,
      jobStore: jobs,
      fileStore: files,
      retention: DefaultRetentionService(jobs, files),
      signer: DownloadTokenSigner(config.downloadSigningKey),
      codeValidator: FakeCodeValidationService(),
      schemaJson: schemaJson,
    );
  }

  LocalRenderGateway gatewayFor(
    RenderRunner runner, {
    String schemaJson = '{}',
    Duration timeout = const Duration(seconds: 10),
  }) => LocalRenderGateway(
    depsFor(runner, schemaJson: schemaJson),
    pollInterval: const Duration(milliseconds: 5),
    timeout: timeout,
    wait: _noWait,
  );

  group('LocalRenderGateway.render', () {
    test('runs a render and returns the finished job with download links', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      final view = await gateway.render(ApiRenderRequest.key('demo'));

      expect(view.isSucceeded, isTrue);
      expect(view.video, isNotNull);
      expect(view.poster, isNotNull);
    });

    test('signs a private download URL by default', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      final view = await gateway.render(ApiRenderRequest.key('demo'));

      expect(view.video!.downloadUrl.queryParameters, contains('token'));
    });

    test('leaves a public download URL unsigned', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      final view = await gateway.render(ApiRenderRequest.key('demo', visibility: 'public'));

      expect(view.video!.downloadUrl.queryParameters, isNot(contains('token')));
    });

    test('accepts an explicit ttl', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      final view = await gateway.render(ApiRenderRequest.key('demo', ttl: '2h'));

      expect(view.isSucceeded, isTrue);
    });

    test('rejects an invalid visibility', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      await expectLater(
        gateway.render(ApiRenderRequest.key('demo', visibility: 'maybe')),
        throwsA(isA<ApiClientException>()),
      );
    });

    test('rejects an unparseable ttl', () async {
      final gateway = gatewayFor(FakeRenderRunner());

      await expectLater(
        gateway.render(ApiRenderRequest.key('demo', ttl: 'soon')),
        throwsA(isA<ApiClientException>()),
      );
    });

    test('throws when the render fails', () async {
      final gateway = gatewayFor(FakeRenderRunner(error: const RenderFailure('boom')));

      await expectLater(
        gateway.render(ApiRenderRequest.key('demo')),
        throwsA(
          isA<ApiClientException>().having((e) => e.message, 'message', contains('boom')),
        ),
      );
    });

    test('times out when the render never finishes', () async {
      final gateway = gatewayFor(_NeverRunner(), timeout: const Duration(milliseconds: 5));

      await expectLater(
        gateway.render(ApiRenderRequest.key('demo')),
        throwsA(
          isA<ApiClientException>().having((e) => e.message, 'message', contains('Timed out')),
        ),
      );
    });
  });

  group('LocalRenderGateway.fetchSpecSchema', () {
    test('returns the decoded schema', () async {
      final gateway = gatewayFor(FakeRenderRunner(), schemaJson: '{"type":"object"}');

      expect(await gateway.fetchSpecSchema(), {'type': 'object'});
    });

    test('throws when the schema is not a JSON object', () async {
      final gateway = gatewayFor(FakeRenderRunner(), schemaJson: '[]');

      await expectLater(gateway.fetchSpecSchema(), throwsA(isA<ApiClientException>()));
    });
  });

  test('close is a no-op (deps are shared, not owned)', () {
    final gateway = gatewayFor(FakeRenderRunner());

    expect(gateway.close, returnsNormally);
  });
}

/// A runner whose render never completes, to exercise the gateway's timeout.
final class _NeverRunner implements RenderRunner {
  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
  }) => Completer<RenderOutcome>().future;
}
