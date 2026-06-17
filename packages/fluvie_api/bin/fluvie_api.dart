import 'dart:io';

import 'package:fluvie_api/server.dart';

/// Starts the Fluvie render API from the process environment.
///
/// Reads `Platform.environment`, reconciles any job left running by a previous
/// process, builds the dependency graph, starts the optional cleanup timer, and
/// serves until SIGINT/SIGTERM. This is process glue; the logic it wires is
/// unit-tested through `buildApp`, `buildServerDependencies`, and the services.
Future<void> main() async {
  final ServerConfig config;
  try {
    config = serverConfigFromEnvironment(Platform.environment);
  } on ServerConfigException catch (error) {
    stderr.writeln('Configuration error: ${error.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  await jobStoreFor(config).reconcileInterruptedJobs();
  final deps = buildServerDependencies(config, schemaJson: _loadSchema());
  final scheduler = RetentionScheduler(deps.retention, interval: config.cleanupInterval)..start();
  final server = await serveFluvieApi(deps);
  stderr.writeln('fluvie_api listening on http://${config.host}:${config.port}');

  Future<void> shutdown(ProcessSignal _) async {
    scheduler.stop();
    await server.close(force: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}

/// Loads the committed VideoSpec schema asset, or `{}` when it is absent.
String _loadSchema() {
  for (final candidate in [
    Platform.environment['VIDEO_SPEC_SCHEMA_PATH'],
    'packages/fluvie_api/assets/video_spec_schema.json',
    '${File(Platform.script.toFilePath()).parent.parent.path}/assets/video_spec_schema.json',
  ]) {
    if (candidate == null) continue;
    final file = File(candidate);
    if (file.existsSync()) return file.readAsStringSync();
  }
  return '{}';
}
