// Task 23: collectClipPlans walks scenes and pairs every clip-painting carrier
// (a Clip element or a Background.video) with the duration of its scene in
// frames and its trim. The clip pre-pass turns each plan into the source frames
// it extracts. A structural walk, no mounting.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/image.dart' as fluvie;

void main() {
  test('pairs each Clip with its scene duration in frames', () {
    final scenes = [
      Scene(duration: const Time.frames(60), children: [Clip.asset('a.mp4')]),
      Scene(duration: const Time.frames(30), children: [Clip.asset('b.mp4')]),
    ];

    final plans = collectClipPlans(scenes, 30, sceneStartFrames: const [0, 60]);

    expect(plans.map((p) => p.source), [
      const MediaSource.asset('a.mp4'),
      const MediaSource.asset('b.mp4'),
    ]);
    expect(plans.map((p) => p.windowLength), [60, 30]);
  });

  test('resolves a seconds duration against the fps', () {
    final scenes = [
      Scene(duration: 2.seconds, children: [Clip.asset('a.mp4')]),
    ];

    expect(collectClipPlans(scenes, 24, sceneStartFrames: const [0]).single.windowLength, 48);
  });

  test('carries the clip trim through to the plan', () {
    final trim = 1.seconds.to(3.seconds);
    final scenes = [
      Scene(
        duration: const Time.frames(90),
        children: [Clip.asset('a.mp4', trim: trim)],
      ),
    ];

    expect(collectClipPlans(scenes, 30, sceneStartFrames: const [0]).single.trim, trim);
  });

  test('a non-clip image source is not collected as a clip plan', () {
    final scenes = [
      Scene(duration: const Time.frames(30), children: [fluvie.Image.asset('photo.png')]),
    ];

    expect(collectClipPlans(scenes, 30, sceneStartFrames: const [0]), isEmpty);
  });

  test("a windowed clip's audio opens where the clip appears, not where its scene does", () {
    final scenes = [
      Scene(
        duration: const Time.frames(150),
        children: [
          Clip.asset('a.mp4').show(from: const Time.frames(30), to: const Time.frames(60)),
        ],
      ),
    ];

    final plan = collectClipAudioPlans(scenes, 30, sceneStartFrames: const [0]).single;

    // startFrame becomes the mix's adelay verbatim, so a scene start here means
    // a clip shown one second in is heard from the top of the scene.
    expect(plan.startFrame, 30);
    expect(plan.windowFrames, 30, reason: 'it plays while it is shown, not for the whole scene');
  });

  test("a windowed clip's plan window is the element's, not the scene's", () {
    final scenes = [
      Scene(
        duration: const Time.frames(150),
        children: [
          Clip.asset('a.mp4').show(from: const Time.frames(30), to: const Time.frames(60)),
        ],
      ),
    ];

    final plan = collectClipPlans(scenes, 30, sceneStartFrames: const [0]).single;

    // The painter resamples against TimeScopeProvider.startFrame, which
    // WindowScope sets to the element window start. Anything else here and the
    // streaming preparer warms a different frame than paint asks for.
    expect(plan.windowStart, 30);
    expect(plan.windowLength, 30);
  });

  test('a window nested inside a window resolves the way it renders', () {
    // WindowScope publishes elementScopeFor(window, nearestScope), so an inner
    // window is relative to the outer one, not to the scene.
    final scenes = [
      Scene(
        duration: const Time.frames(100),
        children: [
          Clip.asset('a.mp4')
              .show(from: const Time.frames(10), to: const Time.frames(20))
              .show(from: const Time.frames(40), to: const Time.frames(90)),
        ],
      ),
    ];

    final plan = collectClipPlans(scenes, 30, sceneStartFrames: const [0]).single;

    // Outer window is 40..90; the inner 10..20 sits inside it, so 50..60.
    expect(plan.windowStart, 50);
    expect(plan.windowLength, 10);
  });

  test('a Background.video is collected with no trim and the scene duration', () {
    final scenes = [
      Scene(duration: const Time.frames(45), background: Background.video('bg.mp4')),
    ];

    final plan = collectClipPlans(scenes, 30, sceneStartFrames: const [0]).single;
    expect(plan.source, const MediaSource.asset('bg.mp4'));
    expect(plan.windowLength, 45);
    expect(plan.trim, isNull);
  });
}
