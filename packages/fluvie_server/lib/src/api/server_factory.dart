import 'dart:io';

import 'package:fluvie_server/src/api/cleanup/default_retention_service.dart';
import 'package:fluvie_server/src/api/config/s3_config.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/jobs/file_job_store.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/ratelimit/in_memory_rate_limiter.dart';
import 'package:fluvie_server/src/api/render/pipeline_render_runner.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/local_file_store.dart';
import 'package:fluvie_server/src/api/storage/minio_object_storage.dart';
import 'package:fluvie_server/src/api/storage/s3_file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/validate/in_process_code_validation_service.dart';
import 'package:minio/minio.dart';

/// Builds the [ServerDependencies] graph from [config]: the file store (local or
/// S3), a file-backed job store, the pipeline render runner + queue, retention,
/// and the download-token signer.
///
/// This is the composition root the server entrypoint calls. Job records live on
/// the local disk (under the storage dir) so they survive a restart even with an
/// S3 file backend; [schemaJson] is the VideoSpec schema to serve.
/// Set [proxyS3Downloads] to stream exports through the API for same-origin
/// browser clients or private buckets that cannot be reached by clients.
ServerDependencies buildServerDependencies(
  ServerConfig config, {
  String schemaJson = '{}',
  JobStore? jobStore,
  Uri? mediaOrigin,
  RenderRunner? renderRunner,
  bool proxyS3Downloads = false,
}) {
  final fileStore = config.storageBackend == StorageBackend.s3
      ? _s3FileStore(config.s3!, proxyDownloads: proxyS3Downloads)
      : LocalFileStore(Directory(config.localStorageDir));
  final jobs = jobStore ?? FileJobStore(Directory('${config.localStorageDir}/.jobs'));
  final queue = RenderQueue(
    runner:
        renderRunner ??
        PipelineRenderRunner(
          renderProject: config.renderProject,
          ffmpegPath: config.ffmpegPath,
          mediaOrigin: mediaOrigin ?? config.publicBaseUrl,
          aiEnv: config.aiEnv,
        ),
    jobStore: jobs,
    fileStore: fileStore,
    fileTtl: config.fileTtl,
    concurrency: config.renderConcurrency,
  );
  return ServerDependencies(
    config: config,
    queue: queue,
    jobStore: jobs,
    fileStore: fileStore,
    retention: DefaultRetentionService(jobs, fileStore),
    signer: DownloadTokenSigner(config.downloadSigningKey),
    codeValidator: InProcessCodeValidationService(
      projectRoot: config.renderProject != null
          ? Directory(config.renderProject!)
          : Directory.current,
    ),
    rateLimiter: InMemoryRateLimiter(
      limit: config.aiRateLimit.limit,
      window: config.aiRateLimit.window,
      dailyQuota: config.aiRateLimit.dailyQuota,
    ),
    schemaJson: schemaJson,
  );
}

/// The file store the [FileJobStore] needs, so a caller can reconcile jobs on
/// boot without rebuilding the whole graph.
FileJobStore jobStoreFor(ServerConfig config) =>
    FileJobStore(Directory('${config.localStorageDir}/.jobs'));

FileStore _s3FileStore(S3Config s3, {required bool proxyDownloads}) => S3FileStore(
  MinioObjectStorage(
    Minio(
      endPoint: s3.endpoint,
      accessKey: s3.accessKey,
      secretKey: s3.secretKey,
      useSSL: s3.useSsl,
      region: s3.region,
      pathStyle: s3.pathStyle,
    ),
    s3.bucket,
  ),
  publicBaseUrl: s3.publicBaseUrl,
  proxyDownloads: proxyDownloads,
);
