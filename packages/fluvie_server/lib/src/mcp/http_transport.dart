import 'dart:convert';

import 'package:fluvie_server/src/mcp/mcp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

/// Builds a shelf handler that serves [server] over Streamable HTTP.
///
/// Clients POST a JSON-RPC message to `/mcp` and get one JSON response back
/// (notifications return `204`). When [token] is set, requests must carry
/// `Authorization: Bearer <token>`. A `/healthz` route reports liveness, and
/// `GET /` returns a human-facing instruction page.
Handler mcpHttpHandler(McpServer server, {String? token}) {
  final router = Router()
    ..get('/', (Request request) => _landingPage(server, tokenRequired: token != null))
    ..get('/healthz', (Request request) => Response.ok('ok'))
    ..post('/mcp', (Request request) => _handlePost(server, request, token));
  return router.call;
}

/// Serves the instruction page: what this MCP server is, how to connect, and the
/// tools it exposes (read live from [server]).
Response _landingPage(McpServer server, {required bool tokenRequired}) {
  final tools = [
    for (final tool in server.tools)
      '  <li><code>${_escape(tool.name)}</code> &mdash; ${_escape(tool.description)}</li>',
  ].join('\n');
  final auth = tokenRequired
      ? '<p>This endpoint is protected. Send <code>Authorization: Bearer &lt;token&gt;</code> '
            'with every request.</p>'
      : '<p>This endpoint is open (no token configured).</p>';
  return Response.ok(
    _page(tools, auth),
    headers: const {'content-type': 'text/html; charset=utf-8'},
  );
}

String _escape(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _page(String tools, String auth) =>
    '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fluvie MCP server</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 42rem; margin: 4rem auto;
         padding: 0 1.25rem; }
  h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
  code { font-family: ui-monospace, monospace; background: rgba(127,127,127,0.18);
         padding: 0.1em 0.35em; border-radius: 4px; }
  pre { background: rgba(127,127,127,0.18); padding: 0.9rem; border-radius: 8px;
        overflow-x: auto; }
  ul { padding-left: 1.2rem; }
  li { margin: 0.35rem 0; }
  a { color: inherit; }
</style>
</head>
<body>
<h1>Fluvie MCP server</h1>
<p>This is a <a href="https://modelcontextprotocol.io">Model Context Protocol</a>
server that lets an AI assistant author and render <a href="https://fluvie.dev">Fluvie</a>
videos. It delegates rendering to a Fluvie render API, so it stays a tiny binary.</p>
<h2>Connect</h2>
<p>The MCP endpoint is <code>POST /mcp</code> (Streamable HTTP, JSON-RPC). Add it to
an MCP client as a remote server:</p>
<pre>{
  "mcpServers": {
    "fluvie": { "url": "https://mcp.fluvie.dev/mcp" }
  }
}</pre>
$auth
<h2>Tools</h2>
<ul>
$tools
</ul>
<h2>Learn more</h2>
<ul>
  <li>Guide: <a href="https://docs.fluvie.dev/guides/ai-and-mcp">AI and MCP</a></li>
  <li>Docs: <a href="https://docs.fluvie.dev">docs.fluvie.dev</a></li>
  <li>Source: <a href="https://github.com/SimonErich/fluvie">github.com/SimonErich/fluvie</a></li>
</ul>
</body>
</html>
''';

Future<Response> _handlePost(McpServer server, Request request, String? token) async {
  if (token != null && request.headers['authorization'] != 'Bearer $token') {
    return Response.forbidden(
      jsonEncode({'error': 'unauthorized'}),
      headers: _jsonHeaders,
    );
  }
  final body = await request.readAsString();
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return Response.badRequest(
      body: jsonEncode({'error': 'invalid JSON'}),
      headers: _jsonHeaders,
    );
  }
  if (decoded is! Map) {
    return Response.badRequest(
      body: jsonEncode({'error': 'expected a JSON-RPC object'}),
      headers: _jsonHeaders,
    );
  }
  final response = await server.handle(decoded.cast<String, Object?>());
  if (response == null) return Response(204);
  return Response.ok(jsonEncode(response), headers: _jsonHeaders);
}
