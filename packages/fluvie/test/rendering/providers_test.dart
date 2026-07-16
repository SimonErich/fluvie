import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/media_resolver_provider_io.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';
import 'package:fluvie/src/media/runtime/stale_temp_sweeper.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
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
  /// An empty throwaway dir for the orphan sweep [mediaResolverProvider] kicks
  /// off when it builds the resolver, so reading the real provider here never
  /// sweeps the machine's actual temp directory.
  StaleTempSweeper hermeticSweeper() {
    final temp = Directory.systemTemp.createTempSync('fluvie_providers_sweep_');
    addTearDown(() => temp.deleteSync(recursive: true));
    return StaleTempSweeper(tempDir: temp);
  }

  /// A container wired to [hermeticSweeper]; the default for every test here
  /// that reads the real [mediaResolverProvider].
  ProviderContainer hermeticContainer() {
    final container = ProviderContainer(
      overrides: [staleTempSweeperProvider.overrideWithValue(hermeticSweeper())],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('rendering providers', () {
    test('a fresh container resolves every provider to its real default', () {
      final container = hermeticContainer();

      expect(container.read(frameCaptureServiceProvider), isA<RepaintBoundaryCaptureService>());
      expect(container.read(processRunnerProvider), isA<IoProcessRunner>());
      expect(container.read(ffmpegRunnerProvider), isA<ProcessFfmpegRunner>());
      expect(container.read(mediaResolverProvider), isA<MediaRepository>());
      expect(container.read(videoProbeServiceProvider), isA<FfprobeVideoProbeService>());
      expect(container.read(frameCacheProvider), isA<FrameCache>());
      expect(container.read(staleTempSweeperProvider), isA<StaleTempSweeper>());
    });

    // The persistent clip-frame cache is what keeps a re-run from re-spawning
    // ffmpeg once per frame; it must reach the real resolver, and it must be
    // the user cache dir, never the temp dir the sweep exists to keep clear.
    test('the real resolver gets the persistent clip frame cache', () {
      final container = hermeticContainer();

      final cache = container.read(clipFrameCacheProvider);
      final resolver = container.read(mediaResolverProvider) as MediaRepository;

      expect(resolver.clipFrameCache, same(cache));
      expect(cache?.root.path, isNot(startsWith(Directory.systemTemp.path)));
    });

    test('the clip frame cache is overridable with a per-test root', () {
      final root = Directory.systemTemp.createTempSync('fluvie_providers_clip_cache_');
      addTearDown(() => root.deleteSync(recursive: true));
      final cache = ClipFrameCache(root);
      final container = ProviderContainer(
        overrides: [
          staleTempSweeperProvider.overrideWithValue(hermeticSweeper()),
          clipFrameCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      expect(
        (container.read(mediaResolverProvider) as MediaRepository).clipFrameCache,
        same(cache),
      );
    });

    // A dead run's orphans are reclaimed by the sweep, and building the
    // resolver is the one place every native run passes through.
    test('building the resolver sweeps orphaned staging dirs', () async {
      final temp = Directory.systemTemp.createTempSync('fluvie_providers_orphan_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final orphan = Directory('${temp.path}/fluvie_clip_frames_DEAD01/key')
        ..createSync(recursive: true);
      File('${orphan.path}/0.rgba')
        ..writeAsBytesSync(const [1])
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));
      final container = ProviderContainer(
        overrides: [staleTempSweeperProvider.overrideWithValue(StaleTempSweeper(tempDir: temp))],
      );
      addTearDown(container.dispose);

      container.read(mediaResolverProvider);
      await pumpEventQueue();

      expect(orphan.parent.existsSync(), isFalse);
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
      final container = hermeticContainer()
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
