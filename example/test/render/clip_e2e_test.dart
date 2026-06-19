// WI-16 (D7/D8/D9): the clip path proven end-to-end through real ffmpeg.
// Tagged `ffmpeg` (a local ffmpeg/ffprobe is required): a real MediaRepository
// probes and extracts frames from the committed clip_1s.mp4 fixture, the
// capture loop paints the resampled frames, RenderService encodes them to MP4,
// and ffprobe verifies the geometry. Excluded from the default test run.
@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _width = 320;
const _height = 240;
const _fps = 30;
const _frames = 15;
const _clip = MediaSource.asset('clip_1s.mp4');

/// The committed test clip, located from the example dir or the repo root.
File _fixture() {
  for (final candidate in const [
    'assets/fixtures/clip_1s.mp4',
    'example/assets/fixtures/clip_1s.mp4',
  ]) {
    final file = File(candidate);
    if (file.existsSync()) return file.absolute;
  }
  fail('clip_1s.mp4 fixture not found.');
}

/// A repository over the on-disk fixture using the real ffmpeg probe/extractor.
MediaRepository _repository() => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _FixtureBundle({'clip_1s.mp4': _fixture()}),
    httpClient: _NoHttp(),
    allowlist: NetworkAllowlist.allowAny(),
  ),
  probeService: const FfprobeVideoProbeService(),
  frameExtractor: const FfmpegFrameExtractionService(),
);

void main() {
  testWidgets('renders a clip composition to a playable MP4 (real ffmpeg)', (tester) async {
    final repo = _repository();
    final outDir = Directory.systemTemp.createTempSync('fluvie_clip_e2e_');
    addTearDown(() => outDir.deleteSync(recursive: true));

    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RenderController();
    final boundaryKey = GlobalKey();
    final service = RenderService(capture: const RepaintBoundaryCaptureService());
    late File output;

    // All real ffmpeg IO (probe, extract, capture, encode) must run on the real
    // event loop — `runAsync` escapes the widget test's fake-async clock.
    await tester.runAsync(() async {
      // The clip is alive for [0, _frames); at 30fps comp == 30fps source the
      // resampler reads source frames 0.._frames-1.
      await repo.preResolveClip(_clip, List<int>.generate(_frames, (i) => i));

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: repo,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: RenderControllerScope(
              controller: controller,
              child: RepaintBoundary(
                key: boundaryKey,
                child: VideoScope(
                  fps: _fps,
                  duration: const Time.frames(_frames),
                  child: SceneScope(
                    duration: const Time.frames(_frames),
                    child: Clip.asset('clip_1s.mp4', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final manifest = await service.captureToDirectory(
        config: RenderConfig(
          width: _width,
          height: _height,
          frameCount: _frames,
          cacheEnabled: false,
        ),
        outDir: outDir,
        pump: (frame) async {
          controller.seek(frame);
          await tester.pump();
        },
        boundaryKey: boundaryKey,
        compositionKey: 'clip_e2e',
      );
      expect(
        File('${outDir.path}/frames.rgba').lengthSync(),
        _frames * _width * _height * 4,
        reason: 'every captured clip frame reaches the raw stream',
      );
      // Encode with the manifest's own ffmpeg arg array.
      final encode = await Process.run(
        'ffmpeg',
        manifest.ffmpegArgs,
        workingDirectory: outDir.path,
      );
      expect(encode.exitCode, 0, reason: '${encode.stderr}');
      output = File('${outDir.path}/${manifest.outputFileName}');
      expect(output.existsSync(), isTrue);
      expect(output.lengthSync(), greaterThan(0));

      // ffprobe verifies the encoded geometry (h264 / 320x240).
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_streams',
        output.path,
      ]);
      expect(probe.exitCode, 0, reason: '${probe.stderr}');
      final report = jsonDecode(probe.stdout as String) as Map<String, Object?>;
      final stream = (report['streams']! as List<Object?>).first! as Map<String, Object?>;
      expect(stream['codec_name'], 'h264');
      expect(stream['width'], _width);
      expect(stream['height'], _height);
    });
  }, tags: ['ffmpeg']);
}

class _NoHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw StateError('no network: $url');
}

class _FixtureBundle extends CachingAssetBundle {
  _FixtureBundle(this._files);
  final Map<String, File> _files;
  @override
  Future<ByteData> load(String key) async {
    final file = _files[key];
    if (file == null) throw StateError('no fixture for "$key"');
    final bytes = await file.readAsBytes();
    return ByteData.view(bytes.buffer);
  }
}
