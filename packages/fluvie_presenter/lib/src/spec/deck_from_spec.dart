import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/src/notes/speaker_notes.dart';
import 'package:fluvie_presenter/src/spec/step_assignment.dart';
import 'package:fluvie_presenter/src/stepping/step_compile_error.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';

/// Builds a presentable deck from [spec]: the `Video` that `VideoSpec.build`
/// produces, with the spec's presentation metadata made real — each `steps`
/// entry becomes a [Stop] and every notes object becomes a [SpeakerNotes].
///
/// Every element builds exactly once, against the one `spec.anchors` table,
/// so trigger identity holds: a `whenEnds` reference and the element that
/// declares the anchor resolve to the same `Anchor` instance, exactly as in
/// `VideoSpec.build`.
///
/// The z-order rule: a step's [Stop] replaces its members at the position of
/// the step's first member in the scene's child order, and inside the stop
/// the members keep that same child order — so revealing elements never
/// restacks them. Step order still follows the spec's `steps` list: each
/// stop carries its step index as an explicit [Stop.order], which beats
/// document position at compile time. Scene notes lead the children as one
/// [SpeakerNotes]; a step's notes ride inside that step's stop.
///
/// Hand the *same* returned `Video` instance to `FluvieSlides` and to any
/// manual `compileSlidePlans`/`compileNotes` call: the step machinery keys
/// stops by widget identity, so two builds of the same spec do not mix.
///
/// The whole build runs inside [ThemeSpec.resolve] with the spec's theme —
/// exactly like `VideoSpec.build` — so `{"token": ...}` references resolve
/// and the theme's motion defaults compose under the explicit ones
/// (`VideoSpec.effectiveMotionDefaults`). Every scene resolves its adopted
/// master first ([resolveSceneMaster]), also exactly like `VideoSpec.build`,
/// so master chrome and placeholder fills present identically to how they
/// render — and a step may reveal a fill by its id, because adoption makes
/// fills scene children.
///
/// The spec's audio tracks thread through unchanged — the video-level list
/// to `Video.audio` and each scene's to `Scene.audio`, exactly as in
/// `VideoSpec.build` — so a presented deck declares the same mix a render
/// would, and its overlays are the same elements outside every scene.
///
/// Throws a [StepCompileError] when a step names an id that is no child of
/// its scene, or an id more than once (`validateStepPlan` collects these
/// instead of throwing).
Video deckFromSpec(VideoSpec spec) => ThemeSpec.resolve(
  spec.theme,
  () => Video(
    size: spec.size,
    fps: spec.fps,
    poster: spec.poster,
    export: spec.export,
    motionDefaults: spec.effectiveMotionDefaults,
    transition: spec.transition,
    // Both rules come from the spec itself rather than being spelled out
    // twice: a muted lane silenced by one builder and played by the other is a
    // deck that sounds different depending on who mounted it.
    audio: spec.buildAudio(),
    overlays: spec.buildOverlays(),
    scenes: [
      for (var s = 0; s < spec.scenes.length; s++)
        _buildScene(resolveSceneMaster(spec.scenes[s], spec.masters), s, spec),
    ],
  ),
);

Scene _buildScene(SceneSpec scene, int sceneIndex, VideoSpec spec) {
  final anchors = spec.anchors;
  final assignment = assignSteps(scene, sceneIndex);
  if (assignment.errors.isNotEmpty) throw assignment.errors.first;
  final built = [for (final child in scene.children) child.build(anchors)];
  final children = <Widget>[
    if (scene.notes case final NotesSpec notes) _speakerNotes(notes),
  ];
  final emitted = <int>{};
  for (var i = 0; i < built.length; i++) {
    final step = assignment.stepOf[i];
    if (step == null) {
      children.add(built[i]);
    } else if (emitted.add(step)) {
      children.add(
        Stop(
          order: step,
          children: [
            for (var j = i; j < built.length; j++)
              if (assignment.stepOf[j] == step) built[j],
            if (scene.steps[step].notes case final NotesSpec notes) _speakerNotes(notes),
          ],
        ),
      );
    }
  }
  return Scene(
    duration: scene.duration,
    background: scene.background?.build(),
    enter: scene.enter,
    exit: scene.exit,
    motionDefaults: scene.motionDefaults,
    audio: [
      for (final track in scene.audio)
        if (!spec.mutedLaneIds.contains(track.lane))
          track.build(laneGain: spec.laneGains[track.lane] ?? 1),
    ],
    children: children,
  );
}

SpeakerNotes _speakerNotes(NotesSpec notes) =>
    SpeakerNotes(text: notes.text, highlights: notes.highlights);
