import 'dart:convert';

import 'package:fluvie_mcp/src/mcp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

/// Builds a shelf handler that serves [server] over Streamable HTTP.
///
/// Clients POST a JSON-RPC message to `/mcp` and get one JSON response back
/// (notifications return `204`). When [token] is set, requests must carry
/// `Authorization: Bearer <token>`. A `/healthz` route reports liveness.
Handler mcpHttpHandler(McpServer server, {String? token}) {
  final router = Router()
    ..get('/healthz', (Request request) => Response.ok('ok'))
    ..post('/mcp', (Request request) => _handlePost(server, request, token));
  return router.call;
}

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
