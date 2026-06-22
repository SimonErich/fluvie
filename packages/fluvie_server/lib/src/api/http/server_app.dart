import 'dart:io';

import 'package:fluvie_server/src/api/http/middleware/cors_middleware.dart';
import 'package:fluvie_server/src/api/http/middleware/error_middleware.dart';
import 'package:fluvie_server/src/api/http/router_factory.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Composes the full request handler: JSON error mapping, CORS, then the router.
///
/// This is the testable seam — drive it with `shelf` [Request]s, no socket.
Handler buildApp(ServerDependencies deps) => const Pipeline()
    .addMiddleware(jsonErrors())
    .addMiddleware(corsHeaders(deps.config.corsAllowOrigins))
    .addHandler(buildRouter(deps).call);

/// Binds [buildApp] to the configured host/port and starts serving.
// coverage:ignore-start: binds a real socket; the handler is covered via buildApp
Future<HttpServer> serveFluvieApi(ServerDependencies deps) =>
    shelf_io.serve(buildApp(deps), deps.config.host, deps.config.port);
// coverage:ignore-end
