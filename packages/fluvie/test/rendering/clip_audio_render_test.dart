// The ffmpeg default render mixes a clip's embedded audio only when the clip
// actually carries an audio track: render() probes each clip, and _audioFor
// gates clip-audio staging on ClipMetadata.hasAudio so a silent clip never
// produces a broken `[N:a]` map.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/render_aspect.dart';
import 'package:fluvie/src/rendering/render_service.dart';

import 'fakes/fake_media_resolver.dart';

const _clip = MediaSource.asset('clip.mp4');
const _clipAudio = AudioSource.asset('clip.mp4');

Future<ui.Image> _frame() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(4, 4);
}

Future<RenderManifest> _renderClip(WidgetTester tester, {required bool hasAudio}) async {
  final image = await _frame();
  addTearDown(image.dispose);
  final audioFile = File(
    '${Directory.systemTemp.createTempSync('fluvie_clip_audio_render_').path}/clip.mp4',
  )..writeAsBytesSync(const [1, 2, 3]);
  addTearDown(() => audioFile.parent.deleteSync(recursive: true));

  final resolver = FakeMediaResolver(
    {_clip: (bytes: Uint8List(0), contentHash: 'x')},
    metadata: {_clip: (fps: 30, frameCount: 30, width: 16, height: 16, hasAudio: hasAudio)},
    clipFrames: {
      _clip: {0: image, 1: image},
    },
    audioPaths: {_clipAudio: audioFile.path},
  );

  tester.view
    ..physicalSize = const ui.Size(16, 16)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_out_');
  addTearDown(() => dir.deleteSync(recursive: true));

  late final RenderAspectResult result;
  await tester.runAsync(() async {
    result = await render(
      composition: Video(
        width: 16,
        height: 16,
        scenes: [
          Scene(duration: const Time.frames(2), children: [Clip.asset('clip.mp4')]),
        ],
      ),
      aspect: Aspect.square,
      longEdge: 16,
      frameCount: 2,
      outDir: dir,
      service: RenderService(capture: const RepaintBoundaryCaptureService(), media: resolver),
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
      resolver: resolver,
    );
  });
  return result.manifest;
}

void main() {
  testWidgets('a clip with audio mixes its embedded track into the encode plan', (tester) async {
    final manifest = await _renderClip(tester, hasAudio: true);
    expect(manifest.ffmpegArgs, contains('-filter_complex'));
    expect(manifest.ffmpegArgs, containsAllInOrder(<String>['-map', '[aout]']));
    expect(manifest.ffmpegArgs, isNot(contains('-an')));
    // The clip's own video file is the audio input.
    expect(manifest.ffmpegArgs.any((a) => a.startsWith('clip_audio_0_')), isTrue);
  });

  testWidgets('a silent clip stays on the -an plan (no broken audio map)', (tester) async {
    final manifest = await _renderClip(tester, hasAudio: false);
    expect(manifest.ffmpegArgs, contains('-an'));
    expect(manifest.ffmpegArgs, isNot(contains('-filter_complex')));
  });
}
