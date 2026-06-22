import 'package:fluvie_server/src/api/http/handlers/download_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/health_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/job_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/maintenance_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/render_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/root_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/schema_handler.dart';
import 'package:fluvie_server/src/api/http/handlers/validate_handler.dart';
import 'package:fluvie_server/src/api/http/middleware/auth_middleware.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds the `/v1` router, applying per-route auth: the API token guards render
/// creation and job status, the cleanup token guards the cleanup endpoint, and
/// the health, schema, and download routes are open (private downloads
/// authenticate inside the handler with a signed token).
Router buildRouter(ServerDependencies deps) {
  final render = RenderHandler(
    queue: deps.queue,
    config: deps.config,
    signer: deps.signer,
    fileStore: deps.fileStore,
  );
  final job = JobHandler(
    jobStore: deps.jobStore,
    fileStore: deps.fileStore,
    config: deps.config,
    signer: deps.signer,
  );
  final download = DownloadHandler(
    jobStore: deps.jobStore,
    fileStore: deps.fileStore,
    config: deps.config,
    signer: deps.signer,
    now: deps.now,
  );
  final maintenance = MaintenanceHandler(deps.retention);
  final health = HealthHandler(deps.fileStore);
  final schema = SchemaHandler(deps.schemaJson);
  final validate = ValidateHandler(validator: deps.codeValidator);
  const root = RootHandler();

  final api = bearerAuth(deps.config.apiToken);
  final cleanup = bearerAuth(deps.config.cleanupToken);

  return Router()
    ..get('/', root.index)
    ..post('/v1/renders', _guard(api, render.create))
    ..post('/v1/validate', _guard(api, validate.validate))
    ..get('/v1/renders/<id>', _guard(api, (request) => job.get(request, _param(request, 'id'))))
    ..get(
      '/v1/files/<id>/<kind>',
      (Request request) => download.get(request, _param(request, 'id'), _param(request, 'kind')),
    )
    ..post('/v1/maintenance/cleanup', _guard(cleanup, maintenance.cleanup))
    ..get('/v1/schema/video-spec', schema.get)
    ..get('/v1/healthz', health.live)
    ..get('/v1/readyz', health.ready);
}

/// Wraps [handler] with the auth [middleware] as a single route handler.
Handler _guard(Middleware middleware, Handler handler) =>
    const Pipeline().addMiddleware(middleware).addHandler(handler);

String _param(Request request, String name) => request.params[name]!;
