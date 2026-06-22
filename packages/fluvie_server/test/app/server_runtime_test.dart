import 'dart:io';

import 'package:fluvie_server/src/app/server_runtime.dart';
import 'package:fluvie_server/src/config/fluvie_server_config.dart';
import 'package:fluvie_server/src/mcp/api_render_gateway.dart';
import 'package:fluvie_server/src/mcp/local_render_gateway.dart';
import 'package:test/test.dart';

import '../support/test_deps.dart';

void main() {
  const apiTokens = {'API_TOKEN': 'tok', 'CLEANUP_TOKEN': 'cleanup'};

  group('buildDocs', () {
    test('loads the corpus when docs are enabled', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_server_rt_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/intro.md').writeAsStringSync('# Intro\nbody');

      final config = FluvieServerConfig.fromEnv({
        'FLUVIE_ENABLE_API': 'false',
        'FLUVIE_DOCS_DIR': dir.path,
      });

      expect(buildDocs(config)!.length, 1);
    });

    test('returns null when docs are disabled', () {
      final config = FluvieServerConfig.fromEnv(const {
        'FLUVIE_ENABLE_API': 'false',
        'FLUVIE_ENABLE_DOCS': 'false',
      });

      expect(buildDocs(config), isNull);
    });
  });

  group('buildRenderGateway', () {
    test('is null when MCP is disabled', () {
      final config = FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_ENABLE_MCP': 'false'});

      expect(buildRenderGateway(config, inMemoryDeps()), isNull);
    });

    test('is null in docs mode', () {
      final config = FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_MCP_MODE': 'docs'});

      expect(buildRenderGateway(config, inMemoryDeps()), isNull);
    });

    test('is a LocalRenderGateway when the API runs in-process', () {
      final config = FluvieServerConfig.fromEnv(const {...apiTokens});

      expect(buildRenderGateway(config, inMemoryDeps()), isA<LocalRenderGateway>());
    });

    test('is an ApiRenderGateway against a remote API when there is no local one', () {
      final config = FluvieServerConfig.fromEnv(const {
        'FLUVIE_ENABLE_API': 'false',
        'FLUVIE_API_URL': 'https://api.fluvie.dev',
      });

      expect(buildRenderGateway(config, null), isA<ApiRenderGateway>());
    });
  });

  group('buildMcpServer', () {
    test('is null when MCP is disabled', () {
      final config = FluvieServerConfig.fromEnv(const {...apiTokens, 'FLUVIE_ENABLE_MCP': 'false'});

      expect(buildMcpServer(config), isNull);
    });

    test('builds a server with the docs and schema tools in docs mode', () {
      final config = FluvieServerConfig.fromEnv(const {'FLUVIE_ENABLE_API': 'false'});

      final server = buildMcpServer(config)!;

      expect(server.tools.map((t) => t.name), contains('get_video_spec_schema'));
    });
  });
}
