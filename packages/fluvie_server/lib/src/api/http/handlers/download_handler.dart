import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:shelf/shelf.dart';

/// Handles `GET /v1/files/{id}/{kind}`: stream the file (local) or redirect to a
/// presigned/public URL (S3). Private files require a signed token or the API
/// bearer.
final class DownloadHandler {
  /// Creates the handler. [now] supplies the time for token verification.
  DownloadHandler({
    required this.jobStore,
    required this.fileStore,
    required this.config,
    required this.signer,
    required this.now,
  });

  /// Where job records live.
  final JobStore jobStore;

  /// Where rendered files live.
  final FileStore fileStore;

  /// The server configuration (download URL TTL, API token).
  final ServerConfig config;

  /// Verifies signed download tokens.
  final DownloadTokenSigner signer;

  /// Supplies the current UTC time for token expiry checks.
  final DateTime Function() now;

  /// Serves the [kind] (`video`|`poster`) file of job [id].
  Future<Response> get(Request request, String id, String kind) async {
    if (kind != 'video' && kind != 'poster') throw const ApiError.notFound();
    final job = await jobStore.get(id);
    if (job == null) throw const ApiError.notFound('No such job');
    final key = kind == 'video' ? job.videoKey : job.posterKey;
    if (key == null) throw const ApiError.notFound('No such file');
    if (job.visibility == StoreVisibility.private && !_authorized(request, id, kind)) {
      throw const ApiError.unauthorized();
    }
    final object = await fileStore.stat(key);
    if (object == null) throw const ApiError.gone('The file has expired');
    final grant = await fileStore.downloadGrant(
      key,
      visibility: job.visibility,
      ttl: config.downloadUrlTtl,
    );
    if (grant.mode == DownloadMode.redirect) {
      return Response.found(grant.url!);
    }
    return Response.ok(
      await fileStore.openRead(key),
      headers: {
        'content-type': object.contentType,
        'content-length': '${object.bytes}',
      },
    );
  }

  bool _authorized(Request request, String id, String kind) {
    final header = request.headers['authorization'];
    if (header == 'Bearer ${config.apiToken}') return true;
    final token = request.url.queryParameters['token'];
    if (token == null) return false;
    final grant = signer.verify(token, now: now());
    return grant != null && grant.jobId == id && grant.kind == kind;
  }
}
