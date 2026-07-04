import 'package:fluvie_server/src/mcp/mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpServerConfig.fromEnv', () {
    test('uses defaults when the environment is empty', () {
      final config = McpServerConfig.fromEnv(const <String, String>{});
      expect(config.apiBaseUrl, Uri.parse('http://localhost:8080'));
      expect(config.apiToken, isNull);
      expect(config.mcpToken, isNull);
      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
    });

    test('reads values from the environment', () {
      final config = McpServerConfig.fromEnv(const {
        'FLUVIE_API_URL': 'https://api.fluvie.dev',
        'FLUVIE_API_TOKEN': 'render-token',
        'FLUVIE_MCP_TOKEN': 'mcp-token',
        'HOST': '127.0.0.1',
        'PORT': '9000',
      });
      expect(config.apiBaseUrl, Uri.parse('https://api.fluvie.dev'));
      expect(config.apiToken, 'render-token');
      expect(config.mcpToken, 'mcp-token');
      expect(config.host, '127.0.0.1');
      expect(config.port, 9000);
    });

    test('treats blank and unparsable values as unset', () {
      final config = McpServerConfig.fromEnv(const {
        'FLUVIE_API_URL': '',
        'FLUVIE_API_TOKEN': '   ',
        'PORT': 'not-a-number',
      });
      expect(config.apiBaseUrl, Uri.parse('http://localhost:8080'));
      expect(config.apiToken, isNull);
      expect(config.port, 8080);
    });

    test('buildGateway returns an ApiRenderGateway', () {
      expect(
        McpServerConfig.fromEnv(const <String, String>{}).buildGateway(),
        isA<ApiRenderGateway>(),
      );
    });
  });
}
