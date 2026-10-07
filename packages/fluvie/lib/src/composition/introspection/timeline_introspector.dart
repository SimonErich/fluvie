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

  // One registration per walked MotionTarget, mirroring RegistrarBinding's
  // token shape — including the enclosing-window inheritance rule.
  final registrationsByScene = <List<ElementRegistration>>[];
  final targetsByScene = <List<_WalkedTarget>>[];
  final overlayRegistrations = <ElementRegistration>[];
  final overlayTargets = <_WalkedTarget>[];
  final root = TimeScopeData(fps: video.fps, startFrame: 0, durationFrames: offsets.totalFrames);
  for (final overlay in video.overlays) {
    _collectTargets(overlay, root, root, null, overlayRegistrations, overlayTargets);
  }
  for (var index = 0; index < video.scenes.length; index++) {
    final scene = video.scenes[index];
    final scope = root.child(
      startFrame: offsets.startFrames[index],
      durationFrames: offsets.durationFrames[index],
    );
    final registrations = <ElementRegistration>[];
    final targets = <_WalkedTarget>[];
    final background = scene.background;
    if (background != null) {
      _collectTargets(background, scope, scope, null, registrations, targets);
    }
    for (final child in scene.children) {
      _collectTargets(child, scope, scope, null, registrations, targets);
    }
    registrationsByScene.add(registrations);
    targetsByScene.add(targets);
  }

  final result = buildVideoPlan(
    fps: video.fps,
    scenes: [
      for (final scene in video.scenes) (duration: scene.duration, defaults: scene.motionDefaults),
    ],
    registrationsByScene: registrationsByScene,
    overlays: overlayRegistrations,
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
      final target = targetsByScene[s][e].target;
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
        elementId: targetsByScene[s][e].elementId,
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
  // The overlays, under the same ownerId shape the plan builder stamps on
  // them, so a row in the timeline and a row here name the same element.
  final overlayElements = <ElementIntrospection>[];
  for (var e = 0; e < overlayRegistrations.length; e++) {
    final registration = overlayRegistrations[e];
    final target = overlayTargets[e].target;
    final schedule = result.schedules[registration]!;
    final element = ElementIntrospection(
      sceneIndex: overlaySceneIndex,
      ownerId: 'oe$e:${registration.debugOwner}',
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
      elementId: overlayTargets[e].elementId,
    );
    overlayElements.add(element);
    byWidget[target] = element;
    byWidget[target.child] = element;
  }
  return TimelineIntrospection._(
    fps: video.fps,
    totalFrames: offsets.totalFrames,
    scenes: List.unmodifiable(scenes),
    overlays: List.unmodifiable(overlayElements),
    byWidget: byWidget,
  );
}

/// A walked `.animate()` wrapper with the spec element id bound to it, or
/// `null` when no [SpecElementId] marker directly wraps it.
typedef _WalkedTarget = ({MotionTarget target, String? elementId});

/// Collects the `.animate()` wrappers at or below [widget] in walk order,
/// threading resolved element scopes down exactly as WindowScope does at
/// runtime, then expressing each registration against its scene origin.
///
/// [directId] is the id of a [SpecElementId] marker whose direct child
/// [widget] is. It binds to [widget] only when [widget] is itself the
/// `.animate()` wrapper — so a marker over a non-animated element binds to
/// nothing and nested elements never inherit an enclosing element's id.
void _collectTargets(
  Widget widget,
  TimeScopeData enclosingScope,
  TimeScopeData ownerScope,
  String? directId,
  List<ElementRegistration> registrations,
  List<_WalkedTarget> targets,
) {
  var scopeBelow = enclosingScope;
  if (widget is MotionTarget) {
    final window = registrationWindowFor(widget.window, enclosingScope, ownerScope);
    registrations.add(
      ElementRegistration(
        debugOwner: widget.anchor?.debugName ?? '${widget.child.runtimeType}',
        anchor: widget.anchor,
        window: window,
        animations: [for (final animation in widget.animations) toAnimationPlan(animation)],
        defaults: widget.defaults,
      ),
    );
    targets.add((target: widget, elementId: directId));
    scopeBelow = elementScopeFor(widget.window, enclosingScope);
  }
  final childId = widget is SpecElementId ? widget.id : null;
  final children = widget is ClipTransitionGroup
      ? widget.resolve(enclosingScope).children
      : declaredChildren(widget);
  for (final child in children) {
    _collectTargets(child, scopeBelow, ownerScope, childId, registrations, targets);
  }
}
