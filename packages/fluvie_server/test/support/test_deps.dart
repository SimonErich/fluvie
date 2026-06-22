import 'dart:io';

import 'package:fluvie_server/src/api/cleanup/default_retention_service.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';

import '../api/render/fakes/fake_render_runner.dart';

/// Builds an in-memory [ServerDependencies] for HTTP/app tests (no disk, no
/// network). The render queue uses a stub runner; most app tests never run it.
ServerDependencies inMemoryDeps({String schemaJson = '{}'}) {
  final config = serverConfigFromEnvironment(const {
    'API_TOKEN': 'tok',
    'CLEANUP_TOKEN': 'cleanup',
  });
  final jobs = InMemoryJobStore();
  final files = InMemoryFileStore();
  final queue = RenderQueue(
    runner: FakeRenderRunner(),
    jobStore: jobs,
    fileStore: files,
    fileTtl: const Duration(hours: 24),
    createWorkDir: (_) async => Directory.systemTemp.createTempSync('fluvie_server_app_'),
  );
  return ServerDependencies(
    config: config,
    queue: queue,
    jobStore: jobs,
    fileStore: files,
    retention: DefaultRetentionService(jobs, files),
    signer: DownloadTokenSigner(config.downloadSigningKey),
    schemaJson: schemaJson,
  );
}
