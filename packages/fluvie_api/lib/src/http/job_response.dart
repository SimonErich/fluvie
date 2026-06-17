import 'package:fluvie_api/src/client/api_render_job.dart';
import 'package:fluvie_api/src/config/server_config.dart';
import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/signed_token.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';

/// Maps a server [RenderJob] to the client [RenderJobView], attaching download
/// links once the render has succeeded.
///
/// Every link points at this server's `/v1/files/{id}/{kind}` endpoint (so the
/// client never sees backend-specific URLs); a private file's link carries an
/// HMAC token valid until the file expires.
Future<RenderJobView> buildJobView(
  RenderJob job, {
  required ServerConfig config,
  required DownloadTokenSigner signer,
  required FileStore fileStore,
}) async {
  FileLink? video;
  FileLink? poster;
  if (job.status == JobStatus.succeeded) {
    video = await _link(job, 'video', job.videoKey, config, signer, fileStore);
    poster = await _link(job, 'poster', job.posterKey, config, signer, fileStore);
  }
  return RenderJobView(
    id: job.id,
    status: job.status.name,
    completed: job.progress?.completed,
    total: job.progress?.total,
    error: job.error,
    video: video,
    poster: poster,
    createdAt: job.createdAt,
    expiresAt: job.expiresAt,
  );
}

Future<FileLink?> _link(
  RenderJob job,
  String kind,
  String? key,
  ServerConfig config,
  DownloadTokenSigner signer,
  FileStore fileStore,
) async {
  if (key == null) return null;
  final stat = await fileStore.stat(key);
  if (stat == null) return null;
  final base = config.publicBaseUrl.resolve('v1/files/${job.id}/$kind');
  final url = job.visibility == StoreVisibility.private
      ? base.replace(
          queryParameters: {
            'token': signer.mint(jobId: job.id, kind: kind, expiresAt: job.expiresAt),
          },
        )
      : base;
  return FileLink(
    downloadUrl: url,
    bytes: stat.bytes,
    contentType: stat.contentType,
    expiresAt: job.expiresAt,
  );
}
