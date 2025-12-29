import 'dart:io';

/// Configuration for the MCP server
class ServerConfig {
  final int port;
  final String host;
  final String docsPath;
  final String? apiKey;
  final String logLevel;
  final bool enableCache;
  final int cacheTtlHours;

  const ServerConfig({
    required this.port,
    required this.host,
    required this.docsPath,
    this.apiKey,
    this.logLevel = 'info',
    this.enableCache = true,
    this.cacheTtlHours = 24,
  });

  /// Create configuration from environment variables
  factory ServerConfig.fromEnvironment() {
    return ServerConfig(
      port: int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080,
      host: Platform.environment['HOST'] ?? '0.0.0.0',
      docsPath: Platform.environment['DOCS_PATH'] ?? './data/docs',
      apiKey: Platform.environment['API_KEY'],
      logLevel: Platform.environment['LOG_LEVEL'] ?? 'info',
      enableCache:
          Platform.environment['ENABLE_CACHE']?.toLowerCase() != 'false',
      cacheTtlHours:
          int.tryParse(Platform.environment['CACHE_TTL_HOURS'] ?? '') ?? 24,
    );
  }

  @override
  String toString() {
    return 'ServerConfig(port: $port, host: $host, docsPath: $docsPath, '
        'logLevel: $logLevel, enableCache: $enableCache)';
  }
}
