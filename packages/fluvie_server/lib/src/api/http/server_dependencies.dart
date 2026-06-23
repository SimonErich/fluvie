import 'package:fluvie_server/src/api/cleanup/retention_service.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/ratelimit/rate_limiter.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';
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
    required this.codeValidator,
    this.rateLimiter = RateLimiter.disabled,
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

  /// Validates submitted Playground code (analysis only; never executes it).
  final CodeValidationService codeValidator;

  /// Guards the LLM-cost render path (prompt/edit) against per-IP abuse.
  ///
  /// Defaults to [RateLimiter.disabled] so non-public deployments and tests opt
  /// in explicitly; the server factory injects the real in-memory limiter.
  final RateLimiter rateLimiter;

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
