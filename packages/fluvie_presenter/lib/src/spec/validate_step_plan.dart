import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/src/spec/deck_from_spec.dart';
import 'package:fluvie_presenter/src/spec/step_assignment.dart';
import 'package:fluvie_presenter/src/stepping/step_compile_error.dart';
import 'package:fluvie_presenter/src/stepping/step_compiler.dart';

/// Checks whether [spec] can present, without mounting anything, and returns
/// every [StepCompileError] found — empty when the deck is clean. The editor
/// calls this live while steps are edited.
///
/// Problems surface together where feasible, in three layers:
///
/// 1. Step references: ids that name no child and ids claimed twice, checked
///    purely and collected across all scenes and steps.
/// 2. The whole deck: `deckFromSpec` plus `compileSlidePlans`, the same path
///    a presentation takes. A clean compile validates the deck.
/// 3. On a compile failure, a scene-by-scene sweep (each scene compiled as
///    its own single-scene deck, sharing `spec.anchors`) collects one error
///    per broken scene, each prefixed with its deck position. A failure the
///    sweep cannot attribute to a single scene reports the whole-deck error.
List<StepCompileError> validateStepPlan(VideoSpec spec) {
  final referenceErrors = <StepCompileError>[
    // Steps are checked against the resolved scene — adoption makes fills
    // scene children, so a step may reveal a fill by its id.
    for (var s = 0; s < spec.scenes.length; s++)
      ...assignSteps(resolveSceneMaster(spec.scenes[s], spec.masters), s).errors,
  ];
  if (referenceErrors.isNotEmpty) return List.unmodifiable(referenceErrors);
  final StepCompileError deckError;
  try {
    compileSlidePlans(deckFromSpec(spec));
    return const [];
  } on StepCompileError catch (error) {
    deckError = error;
  }
  final errors = <StepCompileError>[];
  for (var s = 0; s < spec.scenes.length; s++) {
    try {
      compileSlidePlans(deckFromSpec(_sceneAlone(spec, s)));
    } on StepCompileError catch (error) {
      errors.add(StepCompileError('scene $s: ${error.message}'));
    }
  }
  return List.unmodifiable(errors.isEmpty ? <StepCompileError>[deckError] : errors);
}

/// The scene at [index] as its own single-scene deck. It shares the parent's
/// anchor table, size, fps, motion defaults, theme (its tokens must keep
/// resolving), and masters (an adopting scene must keep resolving); the
/// deck-level transition, poster, and export stay behind — they cannot
/// change how a scene steps.
VideoSpec _sceneAlone(VideoSpec spec, int index) => VideoSpec(
  scenes: [spec.scenes[index]],
  size: spec.size,
  fps: spec.fps,
  motionDefaults: spec.motionDefaults,
  theme: spec.theme,
  masters: spec.masters,
  anchors: spec.anchors,
);
