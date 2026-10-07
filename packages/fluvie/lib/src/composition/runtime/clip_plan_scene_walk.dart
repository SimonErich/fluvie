part of 'clip_plan_collector.dart';

/// Walks every scene's background and children under the scope each widget
/// renders in: the scene's own scope, narrowed by every enclosing element
/// window on the way down.
void _walkScenes(
  List<Scene> scenes,
  int fps,
  List<int> sceneStartFrames,
  List<Widget> overlays,
  int totalFrames,
  void Function(Widget widget, TimeScopeData scope, ClipAudio Function(ClipAudio) audioFor) visit,
) {
  ClipAudio unchanged(ClipAudio audio) => audio;
  void walk(Widget widget, TimeScopeData scope, ClipAudio Function(ClipAudio) audioFor) {
    visit(widget, scope, audioFor);
    final below = widget is MotionTarget ? elementScopeFor(widget.window, scope) : scope;
    final children = widget is ClipTransitionGroup
        ? widget.resolve(scope).children
        : declaredChildren(widget);
    ClipAudio transform(ClipAudio audio) =>
        widget is ClipTransitionAudioScope ? widget.audioFor(audioFor(audio)) : audioFor(audio);
    for (final child in children) {
      walk(child, below, transform);
    }
  }

  assert(
    sceneStartFrames.length == scenes.length,
    // coverage:ignore-line defensive assert message every caller passes the resolved scene starts
    'sceneStartFrames must label every scene: got ${sceneStartFrames.length} '
    'starts for ${scenes.length} scenes.',
  );
  for (var s = 0; s < scenes.length; s++) {
    final scene = scenes[s];
    final sceneScope = TimeScopeData(
      fps: fps,
      startFrame: sceneStartFrames[s],
      durationFrames: resolveSceneDurationFrames(scene.duration, fps, 'scenes[$s]'),
    );
    final background = scene.background;
    if (background != null) walk(background, sceneScope, unchanged);
    for (final child in scene.children) {
      walk(child, sceneScope, unchanged);
    }
  }
  // The overlays, under the video's own scope: an overlay clip's window is
  // measured from frame zero over the whole video, so it extracts the frames
  // it actually plays rather than a scene's worth from a scene's start.
  if (overlays.isEmpty) return;
  final videoScope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  for (final overlay in overlays) {
    walk(overlay, videoScope, unchanged);
  }
}
