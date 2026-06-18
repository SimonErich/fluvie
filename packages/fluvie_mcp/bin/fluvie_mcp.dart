import 'dart:io';

import 'package:fluvie_mcp/fluvie_mcp.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Runs the Fluvie MCP server.
///
/// Default mode is stdio (for a local assistant like Claude Code). Pass `--http`
/// to serve over HTTP (for a hosted endpoint). Configuration comes from the
/// environment; see [McpServerConfig.fromEnv].
Future<void> main(List<String> args) async {
  final config = McpServerConfig.fromEnv(Platform.environment);
  final gateway = config.buildGateway();
  final server = McpServer(name: 'fluvie', version: '0.1.0', tools: buildFluvieTools(gateway));

  if (args.contains('--http')) {
    final handler = mcpHttpHandler(server, token: config.mcpToken);
    final httpServer = await shelf_io.serve(handler, config.host, config.port);
    stderr.writeln('fluvie_mcp on http://${httpServer.address.host}:${httpServer.port}/mcp');
    return;
  }

  await serveStdio(server, input: stdin, output: stdout);
  gateway.close();
}
