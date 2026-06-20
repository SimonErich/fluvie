import 'dart:ffi';

import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:test/test.dart';

void main() {
  group('FfmpegCache on Linux/macOS', () {
    test('prefers XDG_CACHE_HOME when set', () {
      final cache = FfmpegCache(
        abi: Abi.linuxX64,
        environment: const {'XDG_CACHE_HOME': '/xdg', 'HOME': '/home/me'},
      );
      expect(cache.versionDir, '/xdg/fluvie/ffmpeg/$pinnedFfmpegVersion');
      expect(cache.binaryPath, '/xdg/fluvie/ffmpeg/$pinnedFfmpegVersion/ffmpeg');
    });

    test('falls back to ~/.cache when XDG is unset', () {
      final cache = FfmpegCache(
        abi: Abi.macosArm64,
        environment: const {'HOME': '/Users/me'},
      );
      expect(
        cache.binaryPath,
        '/Users/me/.cache/fluvie/ffmpeg/$pinnedFfmpegVersion/ffmpeg',
      );
    });

    test('is null when neither XDG nor HOME is available', () {
      final cache = FfmpegCache(abi: Abi.linuxX64, environment: const <String, String>{});
      expect(cache.rootDir, isNull);
      expect(cache.versionDir, isNull);
      expect(cache.binaryPath, isNull);
    });

    test('honors a custom version label', () {
      final cache = FfmpegCache(
        abi: Abi.linuxX64,
        environment: const {'HOME': '/h'},
        version: '9.9',
      );
      expect(cache.binaryPath, '/h/.cache/fluvie/ffmpeg/9.9/ffmpeg');
    });

    test('defaults to the process environment and host ABI', () {
      expect(FfmpegCache().version, pinnedFfmpegVersion);
    });
  });

  group('FfmpegCache on Windows', () {
    test('uses LOCALAPPDATA and an ffmpeg.exe binary with backslashes', () {
      final cache = FfmpegCache(
        abi: Abi.windowsX64,
        environment: const {'LOCALAPPDATA': r'C:\Users\me\AppData\Local'},
      );
      expect(cache.binaryPath, startsWith(r'C:\Users\me\AppData\Local'));
      expect(cache.binaryPath, contains(r'\fluvie\ffmpeg\'));
      expect(cache.binaryPath, contains(pinnedFfmpegVersion));
      expect(cache.binaryPath, endsWith(r'\ffmpeg.exe'));
    });

    test('is null without LOCALAPPDATA', () {
      final cache = FfmpegCache(abi: Abi.windowsX64, environment: const <String, String>{});
      expect(cache.binaryPath, isNull);
    });
  });
}
