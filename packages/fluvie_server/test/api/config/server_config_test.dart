import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:test/test.dart';

void main() {
  Map<String, String> base() => {'API_TOKEN': 'api', 'CLEANUP_TOKEN': 'clean'};

  group('serverConfigFromEnvironment defaults', () {
    test('applies every documented default', () {
      final config = serverConfigFromEnvironment(base());
      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
      expect(config.publicBaseUrl, Uri.parse('http://localhost:8080'));
      expect(config.storageBackend, StorageBackend.local);
      expect(config.localStorageDir, '/data/renders');
      expect(config.s3, isNull);
      expect(config.publicByDefault, isFalse);
      expect(config.fileTtl, const Duration(hours: 24));
      expect(config.downloadUrlTtl, const Duration(minutes: 15));
      expect(config.cleanupInterval, const Duration(hours: 1));
      expect(config.renderConcurrency, 1);
      expect(config.renderProject, isNull);
      expect(config.ffmpegPath, isNull);
      expect(config.corsAllowOrigins, isEmpty);
      expect(config.aiEnv, isEmpty);
      expect(config.aiRateLimit.limit, 5);
      expect(config.aiRateLimit.window, const Duration(minutes: 1));
      expect(config.aiRateLimit.dailyQuota, 50);
    });

    test('derives the signing key from API_TOKEN when none is set', () {
      final config = serverConfigFromEnvironment(base());
      expect(config.downloadSigningKey, sha256.convert(utf8.encode('fluvie-download:api')).bytes);
    });

    test('uses an explicit signing key when provided', () {
      final config = serverConfigFromEnvironment({...base(), 'DOWNLOAD_SIGNING_KEY': 'secret'});
      expect(config.downloadSigningKey, utf8.encode('secret'));
    });

    test('builds PUBLIC_BASE_URL from the port when unset', () {
      final config = serverConfigFromEnvironment({...base(), 'PORT': '9000'});
      expect(config.publicBaseUrl, Uri.parse('http://localhost:9000'));
    });

    test('parses durations, ints, bools, cors list, and AI passthrough', () {
      final config = serverConfigFromEnvironment({
        ...base(),
        'FILE_TTL': '7d',
        'CLEANUP_INTERVAL': '0s',
        'RENDER_CONCURRENCY': '3',
        'PUBLIC_BY_DEFAULT': 'true',
        'CORS_ALLOW_ORIGINS': 'https://a.test, https://b.test ,',
        'RENDER_PROJECT': '/srv/app',
        'FFMPEG_PATH': '/opt/ffmpeg',
        'FLUVIE_AI_PROVIDER': 'gemini',
        'GEMINI_API_KEY': 'gk',
        'FLUVIE_AI_MODEL': '   ', // blank is ignored
      });
      expect(config.fileTtl, const Duration(days: 7));
      expect(config.cleanupInterval, Duration.zero);
      expect(config.renderConcurrency, 3);
      expect(config.publicByDefault, isTrue);
      expect(config.corsAllowOrigins, ['https://a.test', 'https://b.test']);
      expect(config.renderProject, '/srv/app');
      expect(config.ffmpegPath, '/opt/ffmpeg');
      expect(config.aiEnv, {'FLUVIE_AI_PROVIDER': 'gemini', 'GEMINI_API_KEY': 'gk'});
    });

    test('parses the AI rate-limit env with safe defaults', () {
      final config = serverConfigFromEnvironment({
        ...base(),
        'FLUVIE_AI_RATE_LIMIT': '10',
        'FLUVIE_AI_RATE_WINDOW': '30s',
        'FLUVIE_AI_DAILY_QUOTA': '200',
      });
      expect(config.aiRateLimit.limit, 10);
      expect(config.aiRateLimit.window, const Duration(seconds: 30));
      expect(config.aiRateLimit.dailyQuota, 200);
    });
  });

  group('serverConfigFromEnvironment validation', () {
    test('requires API_TOKEN and CLEANUP_TOKEN', () {
      expect(
        () => serverConfigFromEnvironment(const {'CLEANUP_TOKEN': 'c'}),
        throwsA(isA<ServerConfigException>().having((e) => e.message, 'm', contains('API_TOKEN'))),
      );
      expect(
        () => serverConfigFromEnvironment(const {'API_TOKEN': 'a'}),
        throwsA(
          isA<ServerConfigException>().having((e) => e.message, 'm', contains('CLEANUP_TOKEN')),
        ),
      );
    });

    test('rejects a bad int, bool, duration, and storage backend', () {
      expect(
        () => serverConfigFromEnvironment({...base(), 'PORT': 'x'}),
        throwsA(isA<ServerConfigException>()),
      );
      expect(
        () => serverConfigFromEnvironment({...base(), 'PUBLIC_BY_DEFAULT': 'yes'}),
        throwsA(isA<ServerConfigException>()),
      );
      expect(
        () => serverConfigFromEnvironment({...base(), 'FILE_TTL': 'soon'}),
        throwsA(isA<ServerConfigException>().having((e) => e.message, 'm', contains('FILE_TTL'))),
      );
      expect(
        () => serverConfigFromEnvironment({...base(), 'STORAGE_BACKEND': 'gcs'}),
        throwsA(isA<ServerConfigException>()),
      );
    });
  });

  group('serverConfigFromEnvironment S3', () {
    Map<String, String> s3Base() => {
      ...base(),
      'STORAGE_BACKEND': 's3',
      'S3_ENDPOINT': 's3.test',
      'S3_BUCKET': 'renders',
      'S3_ACCESS_KEY': 'ak',
      'S3_SECRET_KEY': 'sk',
    };

    test('parses the S3 block with defaults and an optional public base', () {
      final config = serverConfigFromEnvironment({
        ...s3Base(),
        'S3_PUBLIC_BASE': 'https://cdn.test',
      });
      final s3 = config.s3!;
      expect(s3.endpoint, 's3.test');
      expect(s3.region, 'us-east-1');
      expect(s3.bucket, 'renders');
      expect(s3.useSsl, isTrue);
      expect(s3.pathStyle, isFalse);
      expect(s3.publicBaseUrl, Uri.parse('https://cdn.test'));
    });

    test('honors S3_USE_SSL/S3_PATH_STYLE and a null public base', () {
      final config = serverConfigFromEnvironment({
        ...s3Base(),
        'S3_USE_SSL': 'false',
        'S3_PATH_STYLE': 'true',
      });
      expect(config.s3!.useSsl, isFalse);
      expect(config.s3!.pathStyle, isTrue);
      expect(config.s3!.publicBaseUrl, isNull);
    });

    test('requires the S3 endpoint/bucket/keys when backend is s3', () {
      expect(
        () => serverConfigFromEnvironment({...base(), 'STORAGE_BACKEND': 's3'}),
        throwsA(
          isA<ServerConfigException>().having((e) => e.message, 'm', contains('S3_ENDPOINT')),
        ),
      );
    });
  });
}
