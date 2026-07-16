part of 'timeline_introspection.dart';

/// Resolves [video]'s timeline without mounting it: a pure, deterministic
/// read of scene bounds and per-element windows.
///
/// The walk sees what fluvie's structural collectors see — each scene's
/// declared children through the common layout widgets, `.animate()`
/// wrappers, and `CollectibleChildren` — so an element hidden inside an
/// opaque custom widget's `build()` is invisible here exactly as it is to
/// media pre-resolution. Windows inherit from enclosing windowed wrappers
/// the same way registrations do at runtime, and the plan resolves through
/// the same pipeline the mounted `Video` runs, minus the theme motion layer
/// (a static read has no `BuildContext` to see a `FluvieTheme` through).
///
/// Throws a [FluvieTimingError] for the same plans a preview would refuse:
/// trigger cycles, dangling anchors, and `Trigger.beat` with no analysed
/// grid.
TimelineIntrospection introspectTimeline(Video video) {
  // One registration per walked MotionTarget, mirroring RegistrarBinding's
  // token shape — including the enclosing-window inheritance rule.
  final registrationsByScene = <List<ElementRegistration>>[];
  final targetsByScene = <List<MotionTarget>>[];
  for (final scene in video.scenes) {
    final registrations = <ElementRegistration>[];
    final targets = <MotionTarget>[];
    final background = scene.background;
    if (background != null) {
      _collectTargets(background, null, registrations, targets);
    }
    for (final child in scene.children) {
      _collectTargets(child, null, registrations, targets);
    }
    registrationsByScene.add(registrations);
    targetsByScene.add(targets);
  }

  final boundaries = resolveBoundaryTransitions(
    scenes: [for (final scene in video.scenes) (enter: scene.enter, exit: scene.exit)],
    videoDefault: video.transition,
  );
  final offsets = resolveSceneOffsets(
    fps: video.fps,
    durations: [for (final scene in video.scenes) scene.duration],
    transitions: boundaries,
    sceneIds: [for (var s = 0; s < video.scenes.length; s++) 'scenes[$s]'],
  );
  final result = buildVideoPlan(
    fps: video.fps,
    scenes: [
      for (final scene in video.scenes) (duration: scene.duration, defaults: scene.motionDefaults),
    ],
    registrationsByScene: registrationsByScene,
    videoDefaults: video.motionDefaults,
    boundaryTransitions: boundaries,
  );

  final byWidget = <Widget, ElementIntrospection>{};
  final scenes = <SceneIntrospection>[];
  for (var s = 0; s < video.scenes.length; s++) {
    final sceneElements = <ElementIntrospection>[];
    final registrations = registrationsByScene[s];
    for (var e = 0; e < registrations.length; e++) {
      final registration = registrations[e];
      final target = targetsByScene[s][e];
      final schedule = result.schedules[registration]!;
      final element = ElementIntrospection(
        sceneIndex: s,
        ownerId: 's${s}e$e:${registration.debugOwner}',
        window: FrameSpan(schedule.window.start, schedule.window.end),
        animations: List.unmodifiable([
          for (var a = 0; a < registration.animations.length; a++)
            AnimationIntrospection(
              phase: registration.animations[a].phase,
              span: FrameSpan(schedule.spans[a].start, schedule.spans[a].end),
              at: registration.animations[a].at,
              label: registration.animations[a].label,
            ),
        ]),
        anchor: registration.anchor,
        key: target.key ?? target.child.key,
      );
      sceneElements.add(element);
      byWidget[target] = element;
      byWidget[target.child] = element;
    }
    scenes.add(
      SceneIntrospection(
        index: s,
        span: FrameSpan(
          offsets.startFrames[s],
          offsets.startFrames[s] + offsets.durationFrames[s],
        ),
        elements: List.unmodifiable(sceneElements),
      ),
    );
  }
  return TimelineIntrospection._(
    fps: video.fps,
    totalFrames: offsets.totalFrames,
    scenes: List.unmodifiable(scenes),
    byWidget: byWidget,
  );
}

/// Collects the `.animate()` wrappers at or below [widget] in walk order,
/// threading the enclosing explicit window down — the static mirror of
/// `WindowScope.maybeWindowOf`: a window-less target inherits the nearest
/// enclosing windowed one, and an explicit window replaces it for the
/// subtree below.
void _collectTargets(
  Widget widget,
  TimeRange? enclosingWindow,
  List<ElementRegistration> registrations,
  List<MotionTarget> targets,
) {
  var windowBelow = enclosingWindow;
  if (widget is MotionTarget) {
    final window = widget.window ?? enclosingWindow;
    registrations.add(
      ElementRegistration(
        debugOwner: widget.anchor?.debugName ?? '${widget.child.runtimeType}',
        anchor: widget.anchor,
        window: window,
        animations: [for (final animation in widget.animations) toAnimationPlan(animation)],
        defaults: widget.defaults,
      ),
    );
    targets.add(widget);
    windowBelow = widget.window ?? enclosingWindow;
  }
  for (final child in declaredChildren(widget)) {
    _collectTargets(child, windowBelow, registrations, targets);
  }
}
