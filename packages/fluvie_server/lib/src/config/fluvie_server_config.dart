import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:meta/meta.dart';

/// The default directory the documentation helper loads markdown from.
const String defaultDocsDir = '/app/documentation';

/// The top-level server configuration, resolved once from the process
/// environment by [FluvieServerConfig.fromEnv].
///
/// It composes the feature toggles (`FLUVIE_ENABLE_API` / `_MCP` / `_DOCS`), the
/// MCP mode, and the render API config ([api], parsed only when the API is on so
/// a docs-only server needs no `API_TOKEN`).
@immutable
final class FluvieServerConfig {
  /// Creates a fully-resolved config (use [FluvieServerConfig.fromEnv]).
  const FluvieServerConfig({
    required this.enableApi,
    required this.enableMcp,
    required this.enableDocs,
    required this.mcpMode,
    required this.host,
    required this.port,
    required this.docsDir,
    required this.api,
    required this.mcpToken,
    required this.remoteApiUrl,
    required this.remoteApiToken,
  });

  /// Resolves the configuration from [env] (typically `Platform.environment`).
  ///
  /// Throws a [ServerConfigException] on a missing or malformed value, including
  /// a required render token when the API is enabled.
  factory FluvieServerConfig.fromEnv(Map<String, String> env) {
    final enableApi = _bool(env, 'FLUVIE_ENABLE_API', fallback: true);
    final enableMcp = _bool(env, 'FLUVIE_ENABLE_MCP', fallback: true);
    final enableDocs = _bool(env, 'FLUVIE_ENABLE_DOCS', fallback: true);
    if (!enableApi && !enableMcp && !enableDocs) {
      throw const ServerConfigException(
        'Enable at least one of FLUVIE_ENABLE_API, FLUVIE_ENABLE_MCP, FLUVIE_ENABLE_DOCS.',
      );
    }

    final api = enableApi ? serverConfigFromEnvironment(env) : null;
    final remoteApiUrl = _uri(env, 'FLUVIE_API_URL');
    final hasRenderBackend = enableApi || remoteApiUrl != null;
    final mcpMode = _mode(env, hasRenderBackend: hasRenderBackend);

    return FluvieServerConfig(
      enableApi: enableApi,
      enableMcp: enableMcp,
      enableDocs: enableDocs,
      mcpMode: mcpMode,
      host: api?.host ?? env['HOST'] ?? '0.0.0.0',
      port: api?.port ?? _port(env),
      docsDir: _trimToNull(env['FLUVIE_DOCS_DIR']) ?? defaultDocsDir,
      api: api,
      mcpToken: _trimToNull(env['FLUVIE_MCP_TOKEN']),
      remoteApiUrl: remoteApiUrl,
      remoteApiToken: _trimToNull(env['FLUVIE_API_TOKEN']),
    );
  }

  /// Whether the render API (`/v1/...`) is mounted.
  final bool enableApi;

  /// Whether the MCP server (HTTP `/mcp` and `--stdio`) is enabled.
  final bool enableMcp;

  /// Whether the documentation helper is enabled.
  final bool enableDocs;

  /// What the MCP server exposes.
  final McpMode mcpMode;

  /// Bind address (default `0.0.0.0`).
  final String host;

  /// Listen port (default `8080`).
  final int port;

  /// The directory the documentation helper loads markdown from.
  final String docsDir;

  /// The render API config, or `null` when the API is disabled.
  final ServerConfig? api;

  /// Bearer token required on the HTTP `/mcp` endpoint, or `null` for open.
  final String? mcpToken;

  /// A remote render API for MCP build mode when the API runs out-of-process.
  final Uri? remoteApiUrl;

  /// The bearer token sent to [remoteApiUrl], or `null` for none.
  final String? remoteApiToken;

  static McpMode _mode(Map<String, String> env, {required bool hasRenderBackend}) {
    final raw = _trimToNull(env['FLUVIE_MCP_MODE']);
    final mode = raw == null
        ? (hasRenderBackend ? McpMode.build : McpMode.docs)
        : _enum(raw, McpMode.values, 'FLUVIE_MCP_MODE');
    if (mode == McpMode.build && !hasRenderBackend) {
      throw const ServerConfigException(
        'FLUVIE_MCP_MODE=build needs a render backend: enable the API or set FLUVIE_API_URL.',
      );
    }
    return mode;
  }

  static Uri? _uri(Map<String, String> env, String key) {
    final raw = _trimToNull(env[key]);
    return raw == null ? null : Uri.parse(raw);
  }

  static int _port(Map<String, String> env) {
    final raw = _trimToNull(env['PORT']);
    if (raw == null) return 8080;
    final value = int.tryParse(raw);
    if (value == null || value < 0) {
      throw const ServerConfigException('PORT must be a non-negative int');
    }
    return value;
  }

  static bool _bool(Map<String, String> env, String key, {required bool fallback}) {
    final raw = _trimToNull(env[key])?.toLowerCase();
    if (raw == null) return fallback;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    throw ServerConfigException('$key must be true or false');
  }

  static T _enum<T extends Enum>(String raw, List<T> values, String key) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw ServerConfigException('$key must be one of ${values.map((v) => v.name).join(', ')}');
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
