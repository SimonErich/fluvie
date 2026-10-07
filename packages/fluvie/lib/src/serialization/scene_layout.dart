part of 'scene_spec.dart';

/// How a scene arranges its children: today's centered stack, or a free
/// canvas where children position themselves through their `transform`.
/// Rendering is identical either way (a `Placed` child self-positions in
/// both); the mode declares authoring intent for tools and validation.
enum SceneLayout {
  /// Children stack centered on the canvas (the default; version 1 files).
  stack,

  /// Children place themselves freely by their `transform`.
  canvas,
}
