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
    this.now = _systemUtcNow,
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

  /// Supplies the current UTC time for download-token verification.
  ///
  /// Defaults to the system clock; tests inject a fixed clock so token expiry is
  /// deterministic instead of racing the calendar (the determinism contract).
  final DateTime Function() now;
}

// The system wall clock in UTC, the production default for ServerDependencies.now.
// coverage:ignore-line: real wall clock; tests inject a fixed clock by contract.
DateTime _systemUtcNow() => DateTime.now().toUtc();
