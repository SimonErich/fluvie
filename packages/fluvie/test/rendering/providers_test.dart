import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';
import 'package:fluvie/src/rendering/platform/ffmpeg_runner_registry.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockFrameCaptureService extends Mock implements FrameCaptureService {}

class _MockProcessRunner extends Mock implements ProcessRunner {}

class _MockFfmpegRunner extends Mock implements FfmpegRunner {}

class _MockMediaResolver extends Mock implements MediaResolver {}

class _MockVideoProbeService extends Mock implements VideoProbeService {}

void main() {
  group('rendering providers', () {
    test('a fresh container resolves every provider to its real default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(frameCaptureServiceProvider), isA<RepaintBoundaryCaptureService>());
      expect(container.read(processRunnerProvider), isA<IoProcessRunner>());
      expect(container.read(ffmpegRunnerProvider), isA<ProcessFfmpegRunner>());
      expect(container.read(mediaResolverProvider), isA<MediaRepository>());
      expect(container.read(videoProbeServiceProvider), isA<FfprobeVideoProbeService>());
      expect(container.read(frameCacheProvider), isA<FrameCache>());
    });

    test('every provider is overridable with a fake', () {
      final capture = _MockFrameCaptureService();
      final runner = _MockProcessRunner();
      final ffmpeg = _MockFfmpegRunner();
      final media = _MockMediaResolver();
      final probe = _MockVideoProbeService();
      final cacheRoot = Directory.systemTemp.createTempSync('fluvie_providers_test_');
      addTearDown(() => cacheRoot.deleteSync(recursive: true));
      final cache = FrameCache(cacheRoot);

      final container = ProviderContainer(
        overrides: [
          frameCaptureServiceProvider.overrideWithValue(capture),
          processRunnerProvider.overrideWithValue(runner),
          ffmpegRunnerProvider.overrideWithValue(ffmpeg),
          mediaResolverProvider.overrideWithValue(media),
          videoProbeServiceProvider.overrideWithValue(probe),
          frameCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(frameCaptureServiceProvider), same(capture));
      expect(container.read(processRunnerProvider), same(runner));
      expect(container.read(ffmpegRunnerProvider), same(ffmpeg));
      expect(container.read(mediaResolverProvider), same(media));
      expect(container.read(videoProbeServiceProvider), same(probe));
      expect(container.read(frameCacheProvider), same(cache));
    });

    test('a container with every provider read disposes cleanly', () {
      final container = ProviderContainer()
        ..read(frameCaptureServiceProvider)
        ..read(processRunnerProvider)
        ..read(ffmpegRunnerProvider)
        ..read(mediaResolverProvider)
        ..read(videoProbeServiceProvider)
        ..read(frameCacheProvider);

      expect(container.dispose, returnsNormally);
    });
  });
}
