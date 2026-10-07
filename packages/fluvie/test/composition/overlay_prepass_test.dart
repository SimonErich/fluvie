// Every pre-pass that resolves media before the frame loop has to see the
// overlays. Nothing here would fail loudly if it did not — an unresolved
// overlay renders the wrong footage rather than throwing — so each collector
// is pinned by hand.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

const _overlayImage = MediaSource.asset('images/overlay.png');
const _sceneImage = MediaSource.asset('images/scene.png');
const _overlayClip = MediaSource.asset('clips/overlay.mp4');

Widget _image(String asset) => Image.asset(asset);

Widget _clip(String asset) => Clip.asset(asset);

Video _video({List<Widget> overlays = const []}) => Video(
  width: 320,
  height: 180,
  overlays: overlays,
  scenes: [
    Scene(
      duration: const Time.frames(60),
      children: [_image('images/scene.png')],
    ),
    const Scene(duration: Time.frames(60), children: [Text('two')]),
  ],
);

void main() {
  group('an overlay image', () {
    test('joins the media pre-pass', () {
      final video = _video(overlays: [_image('images/overlay.png')]);

      expect(collectMediaSources(video.scenes, overlays: video.overlays), contains(_overlayImage));
    });

    test('and is missed when the overlays are not handed over', () {
      // The shape of the bug this guards: the collector's own default is to
      // see scenes only, so a call site that forgets `overlays:` drops it
      // silently.
      final video = _video(overlays: [_image('images/overlay.png')]);

      expect(collectMediaSources(video.scenes), isNot(contains(_overlayImage)));
    });

    test('reaches the whole-composition entry point every renderer uses', () {
      final video = _video(overlays: [_image('images/overlay.png')]);

      expect(collectCompositionMedia(video), contains(_overlayImage));
      expect(collectCompositionMedia(video), contains(_sceneImage));
    });
  });

  group('an overlay clip', () {
    test('is planned against the whole video, not a scene', () {
      // The window is the video's, so the plan extracts the frames the clip
      // actually plays rather than a scene's worth from a scene's start.
      final video = _video(overlays: [_clip('clips/overlay.mp4')]);

      final plans = collectClipPlans(
        video.scenes,
        video.fps,
        sceneStartFrames: video.sceneStartFrames,
        overlays: video.overlays,
        totalFrames: video.totalFrames,
      );

      final plan = plans.singleWhere((p) => p.source == _overlayClip);
      expect(plan.windowStart, 0);
      expect(plan.windowLength, video.totalFrames);
    });

    test('joins the audio mix plan on the same window', () {
      final video = _video(overlays: [_clip('clips/overlay.mp4')]);

      final plans = collectClipAudioPlans(
        video.scenes,
        video.fps,
        sceneStartFrames: video.sceneStartFrames,
        overlays: video.overlays,
        totalFrames: video.totalFrames,
      );

      expect(plans.single.source, _overlayClip);
      expect(plans.single.startFrame, 0);
      expect(plans.single.windowFrames, video.totalFrames);
    });

    test('honours its own show window inside the video scope', () {
      final video = _video(
        overlays: [
          _clip('clips/overlay.mp4').show(from: const Time.frames(30), to: const Time.frames(90)),
        ],
      );

      final plan = collectClipPlans(
        video.scenes,
        video.fps,
        sceneStartFrames: video.sceneStartFrames,
        overlays: video.overlays,
        totalFrames: video.totalFrames,
      ).single;

      expect(plan.windowStart, 30);
      expect(plan.windowLength, 60);
    });
  });

  group('an overlay snapshot', () {
    test('joins the snapshot pre-pass', () {
      final video = _video(overlays: [const Snapshot(child: Text('chart'))]);

      expect(collectSnapshots(video.scenes, overlays: video.overlays), hasLength(1));
    });
  });

  group('an overlay shader', () {
    test('joins the shader pre-load', () {
      final video = _video(
        overlays: [
          const Text('lit').animate([
            Animation.shader('shaders/glow.frag', duration: const Time.frames(10)),
          ]),
        ],
      );

      expect(
        collectShaderAssets(video.scenes, overlays: video.overlays),
        contains('shaders/glow.frag'),
      );
    });
  });

  group('a video with no overlays', () {
    test('collects exactly what it collected before overlays existed', () {
      final video = _video();

      expect(collectMediaSources(video.scenes, overlays: video.overlays), {_sceneImage});
      expect(collectSnapshots(video.scenes, overlays: video.overlays), isEmpty);
      expect(collectShaderAssets(video.scenes, overlays: video.overlays), isEmpty);
    });
  });
}
