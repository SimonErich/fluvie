/// @docImport 'package:fluvie/src/timing/scene_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/composition/runtime/timeline_binder.dart';
import 'package:fluvie/src/composition/timeline.dart';
import 'package:fluvie/src/composition/timeline_schedule.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A time-bounded section of a video — the single source of truth for
/// everything inside it.
///
/// A scene must have a length: [duration] is required, and the type system
/// (not a runtime assert) enforces it. The `Video` parent owns the running
/// offsets and mounts a [SceneScope] above each scene, so a `Scene` renders
/// only its content: a [Stack] aligned to the canvas center — video framing
/// convention, so a bare `Text` child reads well without layout boilerplate.
///
/// Scenes are not standalone widgets: outside a `Video` there is no time
/// scope to resolve against, and building one throws a [FluvieTimingError].
final class Scene extends StatelessWidget {
  /// Creates a scene lasting [duration] showing [children] on its canvas,
  /// optionally over a static [background].
  const Scene({
    required this.duration,
    this.background,
    this.children = const [],
    this.motionDefaults,
    this.audio = const [],
    this.enter,
    this.exit,
    this.camera,
    super.key,
  });

  /// A scene whose duration comes from a [TimelineSchedule] — the scene
  /// lasts exactly as long as the schedule it hosts.
  ///
  /// When [timeline] is a [Timeline] (the timeline authoring surface), the
  /// timeline also *drives* the elements: each [children] entry anchored to a
  /// played target is rebound with the timeline's animation at its resolved
  /// start, so a timeline-driven scene never calls `.animate()` on its own
  /// children. A plain [TimelineSchedule] (no placement plan) contributes
  /// only its [duration]; the children pass through untouched.
  factory Scene.sequence({
    required TimelineSchedule timeline,
    Background? background,
    List<Widget> children = const [],
    Defaults? motionDefaults,
    List<Audio> audio = const [],
    Transition? enter,
    Transition? exit,
    Camera? camera,
    Key? key,
  }) => Scene(
    duration: timeline.duration,
    background: background,
    motionDefaults: motionDefaults,
    audio: audio,
    enter: enter,
    exit: exit,
    camera: camera,
    key: key,
    children: timeline is Timeline ? bindTimeline(timeline, children) : children,
  );

  /// A single-child convenience: [child] mounted centered on the canvas —
  /// `children: [Center(child: child)]`, nothing more.
  Scene.centered({
    required Time duration,
    required Widget child,
    Background? background,
    Defaults? motionDefaults,
    List<Audio> audio = const [],
    Transition? enter,
    Transition? exit,
    Camera? camera,
    Key? key,
  }) : this(
         duration: duration,
         background: background,
         children: [Center(child: child)],
         motionDefaults: motionDefaults,
         audio: audio,
         enter: enter,
         exit: exit,
         camera: camera,
         key: key,
       );

  /// How long the scene lasts. Must be absolute (frames, seconds, or ms):
  /// scene durations define the video length, so a relative duration would
  /// be a fraction of itself.
  final Time duration;

  /// The static backdrop behind [children], or `null` for none. It is
  /// simply the first Stack child — the same [Background] widget works as an
  /// animated, anchored child in [children] instead (the gradient shift).
  final Background? background;

  /// The scene's content, stacked in declaration order and aligned to the
  /// canvas center.
  final List<Widget> children;

  /// Scene-level animation defaults, layered between each element's own
  /// defaults and the video's; `null` inherits unchanged.
  final Defaults? motionDefaults;

  /// Audio tracks scoped to this scene — authoring data the audio pipeline
  /// mounts at render.
  final List<Audio> audio;

  /// The transition this scene wants on the boundary it enters across.
  ///
  /// It wins the boundary precedence: the incoming scene's [enter] beats the
  /// outgoing scene's [exit], which beats the video default. `null` means "no
  /// opinion" — the boundary falls through to the next candidate. An explicit
  /// `Transition.cut()` is a real override that forces a hard cut over a
  /// non-cut video default.
  final Transition? enter;

  /// The transition this scene wants on the boundary it exits across.
  ///
  /// Beaten by the next scene's [enter] and beats the video default in the
  /// boundary precedence; `null` means "no opinion".
  final Transition? exit;

  /// The scene-wide camera move, or `null` for a static frame.
  ///
  /// The move applies *outside* every element transform but inside the
  /// compositor's blend: `Video` mounts a `CameraLayer` for it between this
  /// scene's time scope and its content, so the camera scales the whole scene
  /// image without disturbing per-element animation. The move resolves its
  /// `over` against this scene's scope and holds the end pose after it
  /// completes.
  final Camera? camera;

  @override
  Widget build(BuildContext context) {
    if (TimeScopeProvider.maybeOf(context) == null) {
      throw FluvieTimingError(
        'This Scene has no enclosing time scope: standalone Scenes are '
        'unsupported. Put it in the scenes list of a Video, which owns the '
        'scene offsets and mounts the scope every Time inside resolves '
        'against.',
      );
    }
    return Stack(alignment: Alignment.center, children: [?background, ...children]);
  }
}
