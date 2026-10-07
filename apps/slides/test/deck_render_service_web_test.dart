import 'dart:typed_data';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Aspect, Video, VideoSpec;
import 'package:fluvie/rendering.dart'
    show RenderPhase, RenderProgress, RenderProgressCallback, VideoRenderer;
import 'package:slides/editor/deck_render_service_web.dart';
import 'package:slides/editor/web_export_capability.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
    },
  ],
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'type': 'Text', 'text': 'hello'},
      ],
    },
  ],
};

/// A recording in-browser renderer: captures the request, emits the three
/// phases (with per-frame counts while capturing), and returns fixed bytes.
final class _FakeWebRenderer implements VideoRenderer<Uint8List> {
  ({Widget composition, Aspect aspect, Duration duration, int fps, int longEdge, bool audio})?
  request;

  @override
  Future<Uint8List> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1080,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
  }) async {
    request = (
      composition: composition,
      aspect: aspect,
      duration: duration,
      fps: fps,
      longEdge: longEdge,
      audio: audio,
    );
    onProgress?.call(
      const RenderProgress(RenderPhase.capturing, completedFrames: 12, totalFrames: 60),
    );
    onProgress?.call(const RenderProgress(RenderPhase.encoding));
    onProgress?.call(const RenderProgress(RenderPhase.complete));
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

void main() {
  test('the platform factory reflects the bridge probe (absent on the VM)', () {
    // The conditional import resolves to the VM stub here, so the honest
    // answer is unavailable — exactly what a bridgeless page reports.
    expect(hasFfmpegBridge(), isFalse);
    final service = platformDeckRenderService();
    expect(service.isAvailable, isFalse);
    expect(service.unavailableNote, contains('ffmpeg'));
  });

  test('isAvailable follows the injected bridge probe', () {
    expect(WebDeckRenderService(bridgeProbe: () => true).isAvailable, isTrue);
    expect(WebDeckRenderService(bridgeProbe: () => false).isAvailable, isFalse);
  });

  test('renderToVideo renders the spec-built Video with audio on and delivers it', () async {
    final renderer = _FakeWebRenderer();
    final delivered = <({Uint8List bytes, String filename})>[];
    final phases = <String>[];
    final service = WebDeckRenderService(
      createRenderer: () => renderer,
      deliver: (bytes, filename) async => delivered.add((bytes: bytes, filename: filename)),
      bridgeProbe: () => true,
    );

    final result = await service.renderToVideo(
      spec: VideoSpec.fromJson(_deck()),
      suggestedName: 'mine.mp4',
      onProgress: phases.add,
    );

    // The same spec-built Video the desktop path renders, audio enabled.
    final request = renderer.request!;
    final video = request.composition as Video;
    expect(video.audio, hasLength(1));
    expect(video.audio.single.source, 'audio/bed.mp3');
    expect(request.audio, isTrue);
    expect(request.aspect, Aspect.landscape);
    expect(request.fps, 30);
    expect(request.longEdge, 320);
    expect(request.duration, const Duration(seconds: 2));

    // The progress surface hears human phase lines, frame counts included.
    expect(phases, [
      'Capturing frame 12 of 60',
      'Encoding (ffmpeg.wasm)',
      'Finishing',
    ]);

    // The MP4 lands as a browser download under the suggested name.
    expect(delivered.single.filename, 'mine.mp4');
    expect(delivered.single.bytes, [1, 2, 3]);
    expect(result, 'mine.mp4');
  });

  test('a capturing phase without counts still reads as a phase line', () async {
    final phases = <String>[];
    final service = WebDeckRenderService(
      createRenderer: _CountlessRenderer.new,
      deliver: (bytes, filename) async {},
      bridgeProbe: () => true,
    );
    await service.renderToVideo(
      spec: VideoSpec.fromJson(_deck()),
      suggestedName: 'mine.mp4',
      onProgress: phases.add,
    );
    expect(phases, ['Capturing frames']);
  });
}

final class _CountlessRenderer implements VideoRenderer<Uint8List> {
  @override
  Future<Uint8List> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1080,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
  }) async {
    onProgress?.call(const RenderProgress(RenderPhase.capturing));
    return Uint8List(0);
  }
}
