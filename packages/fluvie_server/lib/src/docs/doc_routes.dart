import 'dart:convert';

import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

/// Builds the optional HTTP mirror of the documentation helper, under `/v1/docs`.
///
/// - `GET /v1/docs` lists pages as `{pages: [{path, title}]}`.
/// - `GET /v1/docs/search?q=...&limit=...` returns `{results: [{path, title, snippet}]}`.
/// - `GET /v1/docs/get?path=...` returns `{path, title, content}` or `404`.
///
/// The MCP tools are the primary surface; this mirror helps plain HTTP clients.
/// It composes as a cascade layer (404 on a non-match) in the unified app.
Handler docRoutes(DocSearchService docs) {
  final router = Router()
    ..get('/v1/docs', (Request request) => _list(docs))
    ..get('/v1/docs/search', (Request request) => _search(docs, request))
    ..get('/v1/docs/get', (Request request) => _get(docs, request));
  return router.call;
}

Response _list(DocSearchService docs) => _ok({
  'pages': [
    for (final entry in docs.list()) {'path': entry.path, 'title': entry.title},
  ],
});

Response _search(DocSearchService docs, Request request) {
  final query = request.url.queryParameters['q'];
  if (query == null || query.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'error': 'q is required'}),
      headers: _jsonHeaders,
    );
  }
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '');
  final hits = docs.search(query, limit: limit != null && limit > 0 ? limit : 5);
  return _ok({
    'results': [
      for (final hit in hits) {'path': hit.path, 'title': hit.title, 'snippet': hit.snippet},
    ],
  });
}

Response _get(DocSearchService docs, Request request) {
  final path = request.url.queryParameters['path'];
  if (path == null || path.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'error': 'path is required'}),
      headers: _jsonHeaders,
    );
  }
  final page = docs.get(path);
  if (page == null) {
    return Response.notFound(
      jsonEncode({'error': 'No documentation page at "$path"'}),
      headers: _jsonHeaders,
    );
  }
  return _ok({'path': page.path, 'title': page.title, 'content': page.body});
}

Response _ok(Object? body) => Response.ok(jsonEncode(body), headers: _jsonHeaders);
