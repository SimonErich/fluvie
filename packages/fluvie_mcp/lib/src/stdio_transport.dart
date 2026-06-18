import 'dart:convert';

import 'package:fluvie_mcp/src/mcp_server.dart';

/// Processes one line of newline-delimited JSON against [server], returning the
/// JSON line to write back, or `null` for notifications and blank/garbage lines.
Future<String?> processStdioLine(McpServer server, String line) async {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final response = await server.handle(decoded.cast<String, Object?>());
  return response == null ? null : jsonEncode(response);
}

/// Serves [server] over stdio: read newline-delimited JSON-RPC from [input] and
/// write each response to [output]. Returns when [input] closes.
///
/// The streams are injected so this is testable without touching real stdio.
Future<void> serveStdio(
  McpServer server, {
  required Stream<List<int>> input,
  required StringSink output,
}) async {
  final lines = input.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    final reply = await processStdioLine(server, line);
    if (reply != null) output.writeln(reply);
  }
}
