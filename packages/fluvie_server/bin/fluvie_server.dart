import 'dart:io';

import 'package:fluvie_server/server.dart';
import 'package:fluvie_server/src/app/server_app.dart';
import 'package:fluvie_server/src/app/server_runtime.dart';
import 'package:fluvie_server/src/config/fluvie_server_config.dart';
import 'package:fluvie_server/src/mcp/local_render_gateway.dart';
import 'package:fluvie_server/src/mcp/stdio_transport.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Starts the Fluvie server from the process environment.
///
/// Default mode serves the enabled features (render API, MCP, docs) over HTTP on
/// one port. Pass `--stdio` to speak MCP over stdin/stdout for a local assistant.
/// Each feature is toggled by `FLUVIE_ENABLE_API` / `_MCP` / `_DOCS`; see the
/// AI and MCP guide. This is process glue; the logic it wires is unit-tested.
Future<void> main(List<String> args) async {
  final FluvieServerConfig config;
  try {
    config = FluvieServerConfig.fromEnv(Platform.environment);
  } on ServerConfigException catch (error) {
    stderr.writeln('Configuration error: ${error.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final schemaJson = _loadSchema();
  final docs = buildDocs(config);
  final deps = config.enableApi
      ? buildServerDependencies(config.api!, schemaJson: schemaJson)
      : null;
  final gateway = buildRenderGateway(config, deps);
  final mcp = buildMcpServer(config, docs: docs, gateway: gateway, schemaJson: schemaJson);

  if (args.contains('--stdio')) {
    if (mcp == null) {
      stderr.writeln('--stdio needs MCP enabled (FLUVIE_ENABLE_MCP must not be false).');
      exitCode = 78;
      return;
    }
    if (gateway is LocalRenderGateway) {
      // No HTTP server runs in stdio mode, so the in-process render's download
      // URL (PUBLIC_BASE_URL) is not reachable. Point at a running server instead.
      stderr.writeln(
        'Warning: --stdio renders in-process; download URLs will point at '
        '${config.api?.publicBaseUrl}, which is not served in stdio mode. '
        'Set FLUVIE_API_URL to a running server for reachable links.',
      );
    }
    await serveStdio(mcp, input: stdin, output: stdout);
    gateway?.close();
    return;
  }

  RetentionScheduler? scheduler;
  if (deps != null) {
    await jobStoreFor(config.api!).reconcileInterruptedJobs();
    scheduler = RetentionScheduler(deps.retention, interval: config.api!.cleanupInterval)..start();
  }
  final handler = buildServerApp(
    api: deps,
    mcp: mcp,
    docs: docs,
    mcpToken: config.mcpToken,
    corsAllowOrigins: config.api?.corsAllowOrigins ?? const [],
  );
  final server = await shelf_io.serve(handler, config.host, config.port);
  stderr.writeln('fluvie_server listening on http://${config.host}:${config.port}');

  Future<void> shutdown(ProcessSignal _) async {
    scheduler?.stop();
    gateway?.close();
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
    'packages/fluvie_server/assets/video_spec_schema.json',
    '${File(Platform.script.toFilePath()).parent.parent.path}/assets/video_spec_schema.json',
  ]) {
    if (candidate == null) continue;
    final file = File(candidate);
    if (file.existsSync()) return file.readAsStringSync();
  }
  return '{}';
}
