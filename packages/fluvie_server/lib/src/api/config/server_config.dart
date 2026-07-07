import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/config/duration_parsing.dart';
import 'package:fluvie_server/src/api/config/s3_config.dart';
import 'package:fluvie_server/src/api/ratelimit/rate_limit_config.dart';
import 'package:fluvie_server/src/config/env_trim.dart';
import 'package:meta/meta.dart';

part 'server_config_from_env.dart';

/// Which storage backend serves rendered files.
enum StorageBackend {
  /// The local filesystem (a mounted volume).
  local,

  /// An S3-compatible bucket.
  s3,
}

/// The full server configuration, resolved once from the process environment by
/// [serverConfigFromEnvironment].
@immutable
final class ServerConfig {
  /// Creates a fully-resolved config (use [serverConfigFromEnvironment]).
  const ServerConfig({
    required this.host,
    required this.port,
    required this.publicBaseUrl,
    required this.apiToken,
    required this.cleanupToken,
    required this.downloadSigningKey,
    required this.storageBackend,
    required this.localStorageDir,
    required this.s3,
    required this.publicByDefault,
    required this.fileTtl,
    required this.downloadUrlTtl,
    required this.cleanupInterval,
    required this.renderConcurrency,
    required this.renderProject,
    required this.ffmpegPath,
    required this.corsAllowOrigins,
    required this.aiEnv,
    required this.aiRateLimit,
  });

  /// Bind address (default `0.0.0.0`).
  final String host;

  /// Listen port (default `8080`).
  final int port;

  /// Base URL used to build absolute download links.
  final Uri publicBaseUrl;

  /// Bearer token guarding render creation and job status.
  final String apiToken;

  /// Bearer token guarding the cleanup endpoint.
  final String cleanupToken;

  /// HMAC key for signed private-download URLs.
  final List<int> downloadSigningKey;

  /// The selected storage backend.
  final StorageBackend storageBackend;

  /// The local storage directory (used when [storageBackend] is local).
  final String localStorageDir;

  /// The S3 settings (non-null when [storageBackend] is s3).
  final S3Config? s3;

  /// Whether a render defaults to public when the request omits visibility.
  final bool publicByDefault;

  /// How long a rendered file stays valid.
  final Duration fileTtl;

  /// How long a presigned/signed download URL stays valid.
  final Duration downloadUrlTtl;

  /// Internal cleanup-timer interval; [Duration.zero] disables it.
  final Duration cleanupInterval;

  /// How many renders run concurrently.
  final int renderConcurrency;

  /// The Flutter project the capture harness runs in, or `null` to auto-discover.
  final String? renderProject;

  /// The ffmpeg binary path, or `null` for `ffmpeg` on PATH.
  final String? ffmpegPath;

  /// Allowed CORS origins (empty = no CORS; `['*']` = any origin).
  final List<String> corsAllowOrigins;

  /// AI provider/model/key env vars forwarded to the render project.
  final Map<String, String> aiEnv;

  /// Per-IP limits applied to the LLM-cost render path (prompt/edit only).
  final RateLimitConfig aiRateLimit;
}

/// Thrown when the environment is missing a required value or holds a bad one.
final class ServerConfigException implements Exception {
  /// Creates the exception with a precise [message].
  const ServerConfigException(this.message);

  /// What was wrong, ready to print to stderr at startup.
  final String message;

  @override
  String toString() => 'ServerConfigException: $message';
}
