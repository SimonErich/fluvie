import 'package:fluvie_server/src/api/http/middleware/cors_middleware.dart';
import 'package:fluvie_server/src/api/http/middleware/error_middleware.dart';
import 'package:fluvie_server/src/api/http/router_factory.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/docs/doc_routes.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/mcp/http_transport.dart';
import 'package:fluvie_server/src/mcp/mcp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Composes the unified request handler from the enabled features.
///
/// A [Cascade] tries each layer until one does not return 404: the base (unified
/// landing + health) first so it owns `/`, then MCP (`POST /mcp`), the docs HTTP
/// mirror (`/v1/docs/...`), and the render API (`/v1/...`). JSON-error and CORS
/// middleware wrap the whole thing. This is the testable seam — drive it with
/// `shelf` [Request]s, no socket.
Handler buildServerApp({
  ServerDependencies? api,
  McpServer? mcp,
  DocSearchService? docs,
  String? mcpToken,
  List<String> corsAllowOrigins = const [],
}) {
  var cascade = Cascade().add(_baseRouter(api: api, mcp: mcp, docs: docs).call);
  if (mcp != null) cascade = cascade.add(mcpHttpHandler(mcp, token: mcpToken));
  if (docs != null) cascade = cascade.add(docRoutes(docs));
  if (api != null) cascade = cascade.add(buildRouter(api).call);

  return const Pipeline()
      .addMiddleware(jsonErrors())
      .addMiddleware(corsHeaders(corsAllowOrigins))
      .addHandler(cascade.handler);
}

Router _baseRouter({
  required ServerDependencies? api,
  required McpServer? mcp,
  required DocSearchService? docs,
}) => Router()
  ..get('/', (Request request) => _landing(api: api, mcp: mcp, docs: docs))
  ..get('/healthz', (Request request) => Response.ok('ok'))
  ..get('/readyz', (Request request) => Response.ok('ready'));

Response _landing({
  required ServerDependencies? api,
  required McpServer? mcp,
  required DocSearchService? docs,
}) {
  final features = <String>[
    if (api != null) '<li>Render API at <code>/v1</code></li>',
    if (mcp != null) '<li>MCP endpoint at <code>POST /mcp</code></li>',
    if (docs != null) '<li>Documentation helper and <code>/v1/docs</code></li>',
  ].join('\n');
  final tools = mcp == null
      ? ''
      : '<h2>MCP tools</h2>\n<ul>\n'
            '${[for (final tool in mcp.tools) '  <li><code>${_escape(tool.name)}</code> &mdash; ${_escape(tool.description)}</li>'].join('\n')}'
            '\n</ul>';
  return Response.ok(
    _page(features, tools),
    headers: const {'content-type': 'text/html; charset=utf-8'},
  );
}

String _escape(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _page(String features, String tools) =>
    '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fluvie server</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 42rem; margin: 4rem auto;
         padding: 0 1.25rem; }
  h1 { font-size: 1.6rem; margin-bottom: 0.25rem; }
  code { font-family: ui-monospace, monospace; background: rgba(127,127,127,0.18);
         padding: 0.1em 0.35em; border-radius: 4px; }
  ul { padding-left: 1.2rem; }
  li { margin: 0.35rem 0; }
  a { color: inherit; }
</style>
</head>
<body>
<h1>Fluvie server</h1>
<p>One self-hostable server for <a href="https://fluvie.dev">Fluvie</a>: the render
API, the MCP server, and a documentation helper. Enabled here:</p>
<ul>
$features
</ul>
$tools
<h2>Learn more</h2>
<ul>
  <li>Guide: <a href="https://docs.fluvie.dev/guides/ai-and-mcp">AI and MCP</a></li>
  <li>Docs: <a href="https://docs.fluvie.dev">docs.fluvie.dev</a></li>
  <li>Source: <a href="https://github.com/SimonErich/fluvie">github.com/SimonErich/fluvie</a></li>
</ul>
</body>
</html>
''';
