import 'dart:convert';

import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/job_response.dart';
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:shelf/shelf.dart';

/// Handles `GET /v1/renders/{id}`: return the job's status (and download links
/// once it has succeeded).
final class JobHandler {
  /// Creates the handler.
  const JobHandler({
    required this.jobStore,
    required this.fileStore,
    required this.config,
    required this.signer,
  });

  /// Where job records live.
  final JobStore jobStore;

  /// Where rendered files live.
  final FileStore fileStore;

  /// The server configuration (base URL for links).
  final ServerConfig config;

  /// Signs private download URLs.
  final DownloadTokenSigner signer;

  /// Returns the status of job [id].
  Future<Response> get(Request request, String id) async {
    final job = await jobStore.get(id);
    if (job == null) throw const ApiError.notFound('No such job');
    // A succeeded job whose video was cleaned up is gone, not found.
    if (job.status == JobStatus.succeeded &&
        job.videoKey != null &&
        await fileStore.stat(job.videoKey!) == null) {
      throw const ApiError.gone('The rendered files have expired');
    }
    final view = await buildJobView(job, config: config, signer: signer, fileStore: fileStore);
    return Response.ok(
      jsonEncode(view.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  }
}
