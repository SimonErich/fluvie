// Phase 8 review fix (D2/D4/D7): Background.video proven against the *real*
// MediaRepository, not just the FakeMediaResolver. The earlier unit test served
// an image for the clip source, so a broken `decodedImageFor` path passed; this
// routes the committed clip_1s.mp4 fixture through the real ffmpeg probe and
// frame extractor, exactly as `Clip` does, and proves a real decoded clip frame
// reaches paint. Tagged `ffmpeg` (a local ffmpeg/ffprobe is required); excluded
// from the default test run.
@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _clip = MediaSource.asset('clip_1s.mp4');
const _fps = 30;
const _frames = 15;

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

/// Mounts [background] in the capture scopes `ClipPainter` reads.
Widget _harness({required Widget background, required MediaRepository repo, int frame = 0}) {
  return ImageResolverScope(
    resolver: repo,
    child: SizedBox(
      width: 320,
      height: 240,
      child: FrameProvider(
        frame: frame,
        child: VideoScope(
          fps: _fps,
          duration: const Time.frames(_frames),
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: SceneScope(duration: const Time.frames(_frames), child: background),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Background.video paints a real decoded clip frame (real ffmpeg)', (tester) async {
    final repo = _repository();

    await tester.runAsync(() async {
      // Pre-resolve the mp4 as a CLIP (probe + extract), the way the harness
      // routes a video source — not as an image. A broken decodedImageFor path
      // would have thrown here under the real repository.
      await repo.preResolveClip(_clip, List<int>.generate(_frames, (i) => i));

      await tester.pumpWidget(_harness(background: Background.video('clip_1s.mp4'), repo: repo));

      final raw = tester.widget<RawImage>(
        find.descendant(of: find.byType(Background), matching: find.byType(RawImage)),
      );
      expect(raw.image, isA<ui.Image>(), reason: 'a real decoded clip frame must reach paint');
      expect(raw.fit, BoxFit.cover);
      // Same source frame the real repository extracted for composition frame 0.
      expect(raw.image, same(repo.decodedClipFrame(_clip, 0)));
    });
  }, tags: ['ffmpeg']);

  testWidgets('Background.video in capture without pre-resolution throws naming the source', (
    tester,
  ) async {
    await tester.pumpWidget(
      RenderModeContext(
        mode: RenderMode.capture,
        child: Background.video('clip_1s.mp4'),
      ),
    );
    expect(
      tester.takeException(),
      isA<FluvieRenderException>().having((e) => e.message, 'message', contains('clip_1s.mp4')),
    );
  });

  tearDownAll(() {
    for (final entry in Directory.systemTemp.listSync()) {
      if (entry is Directory && entry.path.contains('fluvie_clip_src_')) {
        entry.deleteSync(recursive: true);
      }
    }
  });
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
