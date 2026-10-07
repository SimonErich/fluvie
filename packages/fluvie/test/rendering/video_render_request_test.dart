import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

void main() {
  test('prepared facts own immutable source time maps', () {
    final map = <double>[0, 0.25, 0.75];
    const source = MediaSource.asset('cat.mp4');
    final prepared = PreparedComposition(
      video: null,
      clipPlans: [
        (source: source, windowStart: 0, windowLength: 3, trim: null, speed: 1, sourceTimeMap: map),
      ],
      clipAudioPlans: [
        (
          source: source,
          startFrame: 0,
          windowFrames: 3,
          audio: const ClipAudio.included(),
          trim: null,
          speed: 1,
          sourceTimeMap: map,
        ),
      ],
      mediaSources: [source],
      snapshots: [],
      fps: 30,
      totalFrames: 3,
    );
    map[1] = 99;
    expect(prepared.clipPlans.single.sourceTimeMap, [0, 0.25, 0.75]);
    expect(prepared.clipAudioPlans.single.sourceTimeMap, [0, 0.25, 0.75]);
    expect(() => prepared.clipPlans.single.sourceTimeMap![1] = 99, throwsUnsupportedError);
    expect(() => prepared.clipAudioPlans.single.sourceTimeMap!.clear(), throwsUnsupportedError);
  });

  test('explicit quality survives authored MP4 options', () {
    final request = VideoRenderRequest(
      composition: const SizedBox(),
      width: 100,
      height: 80,
      frameCount: 2,
      quality: Quality.low,
    ).withAuthoredOptions(authoredExport: const Export.mp4(crf: 19));
    expect(request.export!.quality, Quality.low);
    expect(request.export!.crf, 19);
  });

  test('a request preserves an arbitrary authored canvas and prefix window', () {
    final request = VideoRenderRequest(
      composition: const SizedBox.shrink(),
      width: 100,
      height: 80,
      fps: 12,
      frameCount: 5,
      startFrame: 2,
      export: const Export.mp4(crf: 20),
      posterFrame: 3,
    );
    expect(request.config.width, 100);
    expect(request.config.height, 80);
    expect(request.config.frameCount, 5);
    expect(request.config.startFrame, 2);
    expect(request.audio, isTrue);
    expect(request.export?.crf, 20);
  });

  test('preflight rejects unsupported choices before custom renderer capture', () {
    final request = VideoRenderRequest(
      composition: const SizedBox.shrink(),
      width: 100,
      height: 80,
      fps: 12,
      frameCount: 5,
      export: const Export.gif(),
    );
    expect(
      () => request.validateCapabilities(RenderCapabilities.mobile),
      throwsA(isA<FluvieCapabilityException>()),
    );
  });
}
