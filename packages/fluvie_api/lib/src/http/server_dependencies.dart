import 'package:fluvie_api/src/cleanup/retention_service.dart';
import 'package:fluvie_api/src/config/server_config.dart';
import 'package:fluvie_api/src/jobs/job_store.dart';
import 'package:fluvie_api/src/jobs/render_queue.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/signed_token.dart';
import 'package:meta/meta.dart';

/// The collaborators the HTTP layer needs, bundled so the router and app builder
/// take one argument.
@immutable
final class ServerDependencies {
  /// Creates the dependency bundle.
  const ServerDependencies({
    required this.config,
    required this.queue,
    required this.jobStore,
    required this.fileStore,
    required this.retention,
    required this.signer,
    this.schemaJson = '{}',
  });

  /// The resolved server configuration.
  final ServerConfig config;

  /// The render queue.
  final RenderQueue queue;

  /// Where job records live.
  final JobStore jobStore;

  /// Where rendered files live.
  final FileStore fileStore;

  /// The retention sweeper.
  final RetentionService retention;

  /// Signs and verifies private download tokens.
  final DownloadTokenSigner signer;

  /// The `VideoSpec` JSON schema served at `/v1/schema/video-spec`.
  final String schemaJson;
}
