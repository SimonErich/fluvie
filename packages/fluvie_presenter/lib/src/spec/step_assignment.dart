import 'package:fluvie/fluvie.dart' show SceneSpec;
import 'package:fluvie_presenter/src/stepping/step_compile_error.dart';

/// Resolves which step each child of [scene] belongs to, collecting every
/// reference problem instead of stopping at the first.
///
/// `stepOf[i]` is the step index claiming child `i`, or null for the base
/// step. An id that names no child, or that a step already claimed, lands in
/// `errors` (phrased with [sceneIndex], the scene's position in its deck) and
/// leaves `stepOf` untouched, so a tool can show every problem at once.
({List<int?> stepOf, List<StepCompileError> errors}) assignSteps(SceneSpec scene, int sceneIndex) {
  final indexOf = <String, int>{
    for (var i = 0; i < scene.children.length; i++)
      if (scene.children[i].id case final String id) id: i,
  };
  final stepOf = List<int?>.filled(scene.children.length, null);
  final claimedBy = <String, int>{};
  final errors = <StepCompileError>[];
  for (var s = 0; s < scene.steps.length; s++) {
    for (final id in scene.steps[s].elements) {
      final index = indexOf[id];
      if (index == null) {
        errors.add(
          StepCompileError(
            'scene $sceneIndex step $s names "$id", which is no child id of '
            'that scene — steps reveal children by their "id".',
          ),
        );
        continue;
      }
      final earlier = claimedBy[id];
      if (earlier != null) {
        errors.add(
          StepCompileError(
            earlier == s
                ? 'scene $sceneIndex step $s names "$id" twice.'
                : 'scene $sceneIndex: "$id" belongs to both step $earlier and '
                      'step $s — an id appears in at most one step.',
          ),
        );
        continue;
      }
      claimedBy[id] = s;
      stepOf[index] = s;
    }
  }
  return (stepOf: stepOf, errors: errors);
}
