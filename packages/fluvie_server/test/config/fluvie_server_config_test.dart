import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/config/fluvie_server_config.dart';
import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:test/test.dart';

void main() {
  // A minimal environment that satisfies the render API's required tokens.
  const apiTokens = {'API_TOKEN': 'tok', 'CLEANUP_TOKEN': 'cleanup'};

  group('FluvieServerConfig.fromEnv', () {
    test('enables every feature by default with the API in build mode', () {
      final config = FluvieServerConfig.fromEnv(apiTokens);

      expect(config.enableApi, isTrue);
      expect(config.enableMcp, isTrue);
      expect(config.enableDocs, isTrue);
      expect(config.mcpMode, McpMode.build);
      expect(config.api, isA<ServerConfig>());
      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
      expect(config.docsDir, '/app/documentation');
    });

    test('takes host and port from the API config when the API is enabled', () {
      final config = FluvieServerConfig.fromEnv(const {
        ...apiTokens,
        'HOST': '127.0.0.1',
        'PORT': '9000',
      });

      expect(config.host, '127.0.0.1');
      expect(config.port, 9000);
      expect(config.api?.port, 9000);
    });

    test('runs docs-only without API tokens when the API is disabled', () {
      final config = FluvieServerConfig.fromEnv(const {'FLUVIE_ENABLE_API': 'false'});

      expect(config.enableApi, isFalse);
      expect(config.api, isNull);
      expect(config.mcpMode, McpMode.docs);
      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
    });

    test('reads host and port directly when the API is disabled', () {
      final config = FluvieServerConfig.fromEnv(const {
        'FLUVIE_ENABLE_API': 'false',
        'HOST': '0.0.0.0',
        'PORT': '7070',
      });

      expect(config.port, 7070);
    });

    test('defaults to build mode when a remote API URL is set without a local API', () {
      final config = FluvieServerConfig.fromEnv(const {
        'FLUVIE_ENABLE_API': 'false',
        'FLUVIE_API_URL': 'https://api.fluvie.dev',
        'FLUVIE_API_TOKEN': 'remote',
      });

      expect(config.mcpMode, McpMode.build);
      expect(config.remoteApiUrl, Uri.parse('https://api.fluvie.dev'));
      expect(config.remoteApiToken, 'remote');
    });

    test('honours an explicit docs mode even when the API is enabled', () {
      final config = FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_MCP_MODE': 'docs'});

      expect(config.mcpMode, McpMode.docs);
    });

    test('rejects build mode when no render backend is available', () {
      expect(
        () => FluvieServerConfig.fromEnv(const {
          'FLUVIE_ENABLE_API': 'false',
          'FLUVIE_MCP_MODE': 'build',
        }),
        throwsA(isA<ServerConfigException>()),
      );
    });

    test('rejects an unknown MCP mode', () {
      expect(
        () => FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_MCP_MODE': 'wat'}),
        throwsA(isA<ServerConfigException>()),
      );
    });

    test('rejects a non-boolean feature flag', () {
      expect(
        () => FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_ENABLE_MCP': 'maybe'}),
        throwsA(isA<ServerConfigException>()),
      );
    });

    test('rejects a configuration with every feature disabled', () {
      expect(
        () => FluvieServerConfig.fromEnv(const {
          'FLUVIE_ENABLE_API': 'false',
          'FLUVIE_ENABLE_MCP': 'false',
          'FLUVIE_ENABLE_DOCS': 'false',
        }),
        throwsA(isA<ServerConfigException>()),
      );
    });

    test('reads the MCP token and a custom docs directory', () {
      final config = FluvieServerConfig.fromEnv(const {
        ...apiTokens,
        'FLUVIE_MCP_TOKEN': 'secret',
        'FLUVIE_DOCS_DIR': '/srv/docs',
      });

      expect(config.mcpToken, 'secret');
      expect(config.docsDir, '/srv/docs');
    });

    test('disables MCP and docs independently', () {
      final config = FluvieServerConfig.fromEnv(const {
        ...apiTokens,
        'FLUVIE_ENABLE_MCP': 'false',
        'FLUVIE_ENABLE_DOCS': 'false',
      });

      expect(config.enableApi, isTrue);
      expect(config.enableMcp, isFalse);
      expect(config.enableDocs, isFalse);
    });
  });
}
