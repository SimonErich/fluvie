import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes/fake_media_resolver.dart';

class _MockMediaResolver extends Mock implements MediaResolver {}

class _MockFfmpegRunner extends Mock implements FfmpegRunner {}

/// Counts every real capture — the spy behind the cache acceptance.
class _CountingCapture implements FrameCaptureService {
  int captures = 0;
  final FrameCaptureService _inner = const RepaintBoundaryCaptureService();

  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) {
    captures++;
    return _inner.capture(
      boundaryKey: boundaryKey,
      frameIndex: frameIndex,
      width: width,
      height: height,
    );
  }
}

/// Paints a solid frame-derived color with integer math only (the demo tree).
class _FrameColorBox extends StatelessWidget {
  const _FrameColorBox();

  @override
  Widget build(BuildContext context) {
    final f = FrameProvider.of(context).frame;
    return ColoredBox(color: Color.fromARGB(255, (f * 5) % 256, (f * 3) % 256, (f * 7) % 256));
  }
}

const int _width = 16;
const int _height = 16;
const int _frameBytes = _width * _height * 4;

RenderConfig _config({int frameCount = 4, int startFrame = 0, bool cacheEnabled = true}) =>
    RenderConfig(
      width: _width,
      height: _height,
      frameCount: frameCount,
      startFrame: startFrame,
      cacheEnabled: cacheEnabled,
    );

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_render_service_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Mounts the demo tree and returns (controller, boundaryKey, pump).
Future<(RenderController, GlobalKey, FramePump)> _mountDemoTree(WidgetTester tester) async {
  tester.view.physicalSize = const ui.Size(_width * 1.0, _height * 1.0);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = RenderController();
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RenderControllerScope(
      controller: controller,
      child: RepaintBoundary(key: boundaryKey, child: const _FrameColorBox()),
    ),
  );
  Future<void> pump(int frame) async {
    controller.seek(frame);
    await tester.pump();
  }

  return (controller, boundaryKey, pump);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<MediaSource>[]);
    registerFallbackValue(<AudioSource>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(Directory('/tmp'));
  });

  group('RenderService.captureToDirectory', () {
    testWidgets('writes frames.rgba with exactly frameCount*w*h*4 bytes', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('len');
      final service = RenderService(capture: _CountingCapture());

      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(File('${outDir.path}/frames.rgba').lengthSync(), 4 * _frameBytes);
    });

    testWidgets('populates the manifest fields and embeds the encode args', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('manifest');
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(manifest.width, _width);
      expect(manifest.height, _height);
      expect(manifest.fps, 30);
      expect(manifest.frameCount, 4);
      expect(manifest.framesFileName, 'frames.rgba');
      expect(manifest.outputFileName, 'out.mp4');
      expect(manifest.renderDigest, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(manifest.ffmpegArgs, service.encoder.planEncodeArgs(_config()));
      expect(File('${outDir.path}/manifest.json').existsSync(), isTrue);
    });

    testWidgets('writes the manifest last (no manifest while frames pump)', (tester) async {
      final (controller, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('last');
      final service = RenderService(capture: _CountingCapture());
      final manifestSeenDuringPump = <bool>[];

      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: (frame) async {
            manifestSeenDuringPump.add(File('${outDir.path}/manifest.json').existsSync());
            await pump(frame);
          },
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(manifestSeenDuringPump, everyElement(isFalse));
      expect(File('${outDir.path}/manifest.json').existsSync(), isTrue);
      expect(controller.frame, 3);
    });

    testWidgets('CACHE: a second run with the same digest captures zero frames', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outA = _tempDir('cache_a');
      final outB = _tempDir('cache_b');
      final cache = FrameCache(_tempDir('cache_root'));
      final first = _CountingCapture();
      final second = _CountingCapture();

      await tester.runAsync(() async {
        await RenderService(capture: first, cache: cache).captureToDirectory(
          config: _config(),
          outDir: outA,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
        await RenderService(capture: second, cache: cache).captureToDirectory(
          config: _config(),
          outDir: outB,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(first.captures, 4);
      expect(second.captures, 0);
      expect(
        File('${outB.path}/frames.rgba').readAsBytesSync(),
        File('${outA.path}/frames.rgba').readAsBytesSync(),
      );
    });

    testWidgets('cacheEnabled: false always captures', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final cache = FrameCache(_tempDir('nocache_root'));
      final first = _CountingCapture();
      final second = _CountingCapture();

      await tester.runAsync(() async {
        await RenderService(capture: first, cache: cache).captureToDirectory(
          config: _config(),
          outDir: _tempDir('nocache_a'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
        await RenderService(capture: second, cache: cache).captureToDirectory(
          config: _config(cacheEnabled: false),
          outDir: _tempDir('nocache_b'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(first.captures, 4);
      expect(second.captures, 4, reason: 'cacheEnabled: false must bypass the cache');
    });

    testWidgets('preResolveAll runs before the first pump', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final media = _MockMediaResolver();
      final events = <String>[];
      when(() => media.preResolveAll(any())).thenAnswer((_) async {
        events.add('preResolveAll');
      });
      when(() => media.preResolveAudio(any())).thenAnswer((_) async {});
      final service = RenderService(capture: _CountingCapture(), media: media);
      const source = MediaSource.asset('logo.png');

      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(frameCount: 2),
          outDir: _tempDir('media'),
          pump: (frame) async {
            events.add('pump:$frame');
            await pump(frame);
          },
          boundaryKey: key,
          compositionKey: 'demo',
          mediaSources: [source],
        );
      });

      expect(events, ['preResolveAll', 'pump:0', 'pump:1']);
      verify(() => media.preResolveAll([source])).called(1);
    });

    testWidgets('onProgress reports each frame in order, ending at count/count', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final reports = <(int, int)>[];
      final service = RenderService(capture: _CountingCapture());

      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(),
          outDir: _tempDir('progress'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          onProgress: (completed, total) => reports.add((completed, total)),
        );
      });

      expect(reports, [(1, 4), (2, 4), (3, 4), (4, 4)]);
    });

    testWidgets('onProgress fires for cache-hit frames too (replay still reports)', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final cache = FrameCache(_tempDir('progress_cache_root'));
      final reports = <(int, int)>[];

      await tester.runAsync(() async {
        // Warm the cache, then a second run replays every frame from disk.
        await RenderService(capture: _CountingCapture(), cache: cache).captureToDirectory(
          config: _config(frameCount: 3),
          outDir: _tempDir('progress_warm'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
        final second = _CountingCapture();
        await RenderService(capture: second, cache: cache).captureToDirectory(
          config: _config(frameCount: 3),
          outDir: _tempDir('progress_replay'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          onProgress: (completed, total) => reports.add((completed, total)),
        );
        expect(second.captures, 0, reason: 'the second run must be all cache hits');
      });

      expect(reports, [(1, 3), (2, 3), (3, 3)]);
    });

    testWidgets('pump receives startFrame..startFrame+count-1 in order', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final pumped = <int>[];
      final service = RenderService(capture: _CountingCapture());

      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(frameCount: 3, startFrame: 5),
          outDir: _tempDir('window'),
          pump: (frame) async {
            pumped.add(frame);
            await pump(frame);
          },
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(pumped, [5, 6, 7]);
    });
  });

  group('RenderService export + poster wiring (WI-20)', () {
    testWidgets('a gif export carries the palette args and out.gif output', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('gif');
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          export: const Export.gif(fps: 12),
        );
      });

      expect(manifest.outputFileName, 'out.gif');
      expect(manifest.ffmpegArgs, contains('-filter_complex'));
      expect(
        manifest.ffmpegArgs,
        service.encoder.planEncodeArgs(_config(), export: const Export.gif(fps: 12)),
      );
      expect(manifest.posterArgs, isNull);
    });

    testWidgets('export: null leaves the manifest byte-identical to the mp4 default', (
      tester,
    ) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('mp4');
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
        );
      });

      expect(manifest.outputFileName, 'out.mp4');
      expect(manifest.ffmpegArgs, service.encoder.planEncodeArgs(_config()));
      expect(manifest.posterArgs, isNull);
      expect(manifest.posterFileName, isNull);
    });

    testWidgets('a poster frame adds the second poster invocation', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('poster');
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          posterFrame: 2,
        );
      });

      expect(manifest.posterFileName, 'poster.png');
      expect(manifest.posterArgs, isNotNull);
      expect(manifest.posterArgs, service.encoder.planPosterArgs(_config(), posterFrame: 2));
      expect(manifest.posterArgs, contains(r'select=eq(n\,2)'));
    });

    testWidgets('DETERMINISM: same export+poster produces identical manifest args', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest a;
      late final RenderManifest b;
      await tester.runAsync(() async {
        a = await service.captureToDirectory(
          config: _config(cacheEnabled: false),
          outDir: _tempDir('det_export_a'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          export: const Export.transparent(),
          posterFrame: 1,
        );
        b = await service.captureToDirectory(
          config: _config(cacheEnabled: false),
          outDir: _tempDir('det_export_b'),
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          export: const Export.transparent(),
          posterFrame: 1,
        );
      });

      expect(a.ffmpegArgs, b.ffmpegArgs);
      expect(a.posterArgs, b.posterArgs);
      expect(a.outputFileName, 'out.webm');
    });
  });

  group('RenderService.render', () {
    testWidgets('hands the manifest args and sandbox to the provider', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('render');
      final provider = _MockFfmpegRunner();
      when(
        () => provider.encode(
          args: any(named: 'args'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async {});
      final service = RenderService(capture: _CountingCapture());

      late final File output;
      await tester.runAsync(() async {
        output = await service.render(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          runner: provider,
        );
      });

      verify(
        () => provider.encode(args: service.encoder.planEncodeArgs(_config()), sandbox: outDir),
      ).called(1);
      expect(output.path, '${outDir.path}/out.mp4');
    });

    testWidgets('a poster export runs the second poster invocation too', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('render_poster');
      final provider = _MockFfmpegRunner();
      when(
        () => provider.encode(
          args: any(named: 'args'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async {});
      final service = RenderService(capture: _CountingCapture());

      late final File output;
      await tester.runAsync(() async {
        output = await service.render(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'demo',
          runner: provider,
          export: const Export.gif(),
          posterFrame: 1,
        );
      });

      verify(
        () => provider.encode(
          args: service.encoder.planEncodeArgs(_config(), export: const Export.gif()),
          sandbox: outDir,
        ),
      ).called(1);
      verify(
        () => provider.encode(
          args: service.encoder.planPosterArgs(_config(), posterFrame: 1),
          sandbox: outDir,
        ),
      ).called(1);
      expect(output.path, '${outDir.path}/out.gif');
    });
  });

  group('MediaSource collection path (WI-12)', () {
    testWidgets('the collected sources are pre-resolved before frame 0, image present', (
      tester,
    ) async {
      tester.view.physicalSize = const ui.Size(_width * 1.0, _height * 1.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A solid green swatch, decoded and pre-resolved through a fake resolver.
      final decoded = await _solidGreen();
      addTearDown(decoded.dispose);
      const asset = MediaSource.asset('fixtures/swatch.png');
      final resolver = FakeMediaResolver(
        {asset: (bytes: Uint8List(0), contentHash: 'x')},
        images: {asset: decoded},
      );

      // The declared composition the collector reads (no mounting).
      final scenes = [
        Scene(
          duration: const Time.frames(4),
          children: [Image.asset('fixtures/swatch.png', fit: BoxFit.fill)],
        ),
      ];
      final collected = collectMediaSources(scenes);
      expect(collected, {asset});

      // The harness pre-resolves the collected sources *before* the tree is
      // mounted at frame 0, so the first build paints synchronously.
      await tester.runAsync(() => resolver.preResolveAll(collected));

      final controller = RenderController();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: ImageResolverScope(
            resolver: resolver,
            child: RenderControllerScope(
              controller: controller,
              child: RepaintBoundary(
                key: boundaryKey,
                child: Image.asset('fixtures/swatch.png', fit: BoxFit.fill),
              ),
            ),
          ),
        ),
      );

      final service = RenderService(capture: _CountingCapture(), media: resolver);
      final outDir = _tempDir('collect');
      await tester.runAsync(() async {
        await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: (frame) async {
            controller.seek(frame);
            await tester.pump();
          },
          boundaryKey: boundaryKey,
          compositionKey: 'image',
          mediaSources: collected,
        );
      });

      // Frame 0's first pixel is the swatch green — the image was resolved and
      // painted synchronously, no async pop-in.
      final bytes = File('${outDir.path}/frames.rgba').readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x2E, 0xCC, 0x71, 0xFF]);
    });
  });

  group('audio mix path (WI-6)', () {
    AudioMixStager stagerFor(List<Audio> tracks, {int fps = 30}) =>
        ({required resolver, required sandbox}) async {
          final plan = await stageAudioMix(
            tracks: tracks,
            resolver: resolver,
            sandbox: sandbox,
            fps: fps,
          );
          return (nodes: plan.tracks, amix: plan.amix);
        };

    testWidgets('one music track maps an AudioTrackNode into the encode plan', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('audio_one');
      final srcDir = _tempDir('audio_src');
      final src = File('${srcDir.path}/song.bin')..writeAsBytesSync(const [1, 2, 3]);

      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(const {}, audioPaths: {song: src.path});
      final service = RenderService(capture: _CountingCapture(), media: resolver);

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'audio',
          audioSources: const [song],
          stageAudio: stagerFor(const [Audio.music('audio/song.mp3')]),
        );
      });

      expect(manifest.ffmpegArgs, contains('-filter_complex'));
      expect(manifest.ffmpegArgs, containsAllInOrder(<String>['-map', '0:v:0', '-map', '[aout]']));
      expect(manifest.ffmpegArgs, containsAllInOrder(<String>['-c:a', 'aac', '-b:a', '192k']));
      expect(manifest.ffmpegArgs, isNot(contains('-an')));
    });

    testWidgets('a silent composition keeps the -an plan unchanged', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final outDir = _tempDir('audio_none');
      final service = RenderService(capture: _CountingCapture());

      late final RenderManifest manifest;
      await tester.runAsync(() async {
        manifest = await service.captureToDirectory(
          config: _config(),
          outDir: outDir,
          pump: pump,
          boundaryKey: key,
          compositionKey: 'silent',
          stageAudio: stagerFor(const []),
        );
      });

      expect(manifest.ffmpegArgs, contains('-an'));
      expect(manifest.ffmpegArgs, isNot(contains('-filter_complex')));
      expect(manifest.ffmpegArgs, service.encoder.planEncodeArgs(_config()));
    });

    testWidgets('DETERMINISM: the same track yields a byte-identical arg array', (tester) async {
      final (_, key, pump) = await _mountDemoTree(tester);
      final srcDir = _tempDir('audio_det_src');
      final src = File('${srcDir.path}/song.bin')..writeAsBytesSync(const [7, 7, 7]);
      const song = AudioSource.asset('audio/song.mp3');

      Future<List<String>> runOnce(String label) async {
        final outDir = _tempDir(label);
        final resolver = FakeMediaResolver(const {}, audioPaths: {song: src.path});
        final service = RenderService(capture: _CountingCapture(), media: resolver);
        late final RenderManifest manifest;
        await tester.runAsync(() async {
          manifest = await service.captureToDirectory(
            config: _config(),
            outDir: outDir,
            pump: pump,
            boundaryKey: key,
            compositionKey: 'audio',
            audioSources: const [song],
            stageAudio: stagerFor(const [Audio.music('audio/song.mp3')]),
          );
        });
        return manifest.ffmpegArgs;
      }

      expect(await runOnce('audio_det_a'), await runOnce('audio_det_b'));
    });
  });
}

/// A solid green swatch used by the collection-path capture test.
Future<ui.Image> _solidGreen() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}
