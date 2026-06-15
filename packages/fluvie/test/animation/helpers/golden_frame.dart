import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// One scenario per frame: each mounts a fresh [subject] under its own
/// frame clock and timing scopes, so a single golden file shows the motion
/// at every probed frame side by side (decision D20).
///
/// No seeking happens — every scenario is a static
/// `RenderControllerScope(RenderController(initialFrame: f))` →
/// `VideoScope` → `SceneScope` → subject, which is exactly the determinism
/// contract: the frame is the only clock.
GoldenTestGroup motionFrameGroup({
  required Widget Function() subject,
  required List<int> frames,
  int fps = 30,
  int sceneFrames = 60,
  Size size = const Size(120, 120),
}) => GoldenTestGroup(
  children: [
    for (final frame in frames)
      _scenario(
        name: 'frame $frame',
        frame: frame,
        subject: subject,
        fps: fps,
        sceneFrames: sceneFrames,
        size: size,
      ),
  ],
);

/// One scenario per named subject, all clocked at the same [frame] — for
/// goldens comparing preset variants (edges, wipe shapes) side by side at one
/// representative moment (decision D20).
GoldenTestGroup motionVariantsGroup({
  required List<(String, Widget Function())> variants,
  required int frame,
  int fps = 30,
  int sceneFrames = 60,
  Size size = const Size(120, 120),
}) => GoldenTestGroup(
  children: [
    for (final (name, subject) in variants)
      _scenario(
        name: name,
        frame: frame,
        subject: subject,
        fps: fps,
        sceneFrames: sceneFrames,
        size: size,
      ),
  ],
);

GoldenTestScenario _scenario({
  required String name,
  required int frame,
  required Widget Function() subject,
  required int fps,
  required int sceneFrames,
  required Size size,
}) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: VideoScope(
        fps: fps,
        duration: Time.frames(sceneFrames),
        child: SceneScope(duration: Time.frames(sceneFrames), child: subject()),
      ),
    ),
  ),
);

/// Registers one Alchemist golden test snapshotting [subject] at every frame
/// in [frames] (one [GoldenTestScenario] each, via [motionFrameGroup]).
///
/// Subjects must stay font-free (ColoredBox squares, no text) so the goldens
/// carry zero font variance (decision D20). [sceneFrames] is both the video
/// and the single scene length; [size] bounds each scenario.
Future<void> goldenMotionFrames({
  required String description,
  required String fileName,
  required Widget Function() subject,
  required List<int> frames,
  int fps = 30,
  int sceneFrames = 60,
  Size size = const Size(120, 120),
}) => goldenTest(
  description,
  fileName: fileName,
  builder: () => motionFrameGroup(
    subject: subject,
    frames: frames,
    fps: fps,
    sceneFrames: sceneFrames,
    size: size,
  ),
);

/// Registers one Alchemist golden test snapshotting every named variant in
/// [variants] at the same [frame] (one [GoldenTestScenario] each, via
/// [motionVariantsGroup]). Subjects stay font-free per [goldenMotionFrames].
Future<void> goldenMotionVariants({
  required String description,
  required String fileName,
  required List<(String, Widget Function())> variants,
  required int frame,
  int fps = 30,
  int sceneFrames = 60,
  Size size = const Size(120, 120),
}) => goldenTest(
  description,
  fileName: fileName,
  builder: () => motionVariantsGroup(
    variants: variants,
    frame: frame,
    fps: fps,
    sceneFrames: sceneFrames,
    size: size,
  ),
);
