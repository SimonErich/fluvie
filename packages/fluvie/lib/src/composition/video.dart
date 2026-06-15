import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/captions/runtime/captions_layer.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/composition/camera/camera_layer.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/composition/runtime/video_plan_builder.dart';
import 'package:fluvie/src/composition/runtime/video_registrar.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/transition/boundary_resolver.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/video_scope.dart';

part 'video_state.dart';

/// The root of a composition: scenes in, one video out.
///
/// A `Video` computes its total duration from its [scenes] — you never sum
/// anything. Every scene stays mounted in one shared, expanding [Stack]
/// under a [TransitionCompositor] that shows each scene only
/// during its frame window and blends adjacent scenes across their boundaries,
/// with a [SceneScope] at the scene's running offset giving everything inside
/// the right time scope. The same shared offset math backs
/// [totalFrames], [sceneStartFrames], and the compositor, so the widget tree
/// and the timing resolver can never disagree on scene boundaries.
///
/// The State owns the composition registrar: every animated
/// element under the video registers itself during the first build, a
/// post-frame pass resolves the whole plan **once**, and the next pump
/// renders every element from its injected schedule — cross-element and
/// scene/video `Defaults` cascading included.
///
/// [transition] is the video-wide default blend between adjacent scenes.
/// Per-scene `Scene.enter`/`Scene.exit` override it boundary by boundary;
/// `null` everywhere means hard cuts. An overlapping transition starts the
/// next scene early and shortens [totalFrames].
///
/// [captions] mount as the top scene-spanning overlay: the layer shows the
/// active cue at the current frame, styled and positioned, reading the cues
/// the render shell pre-parsed before frame 0. [audio] and [export] are
/// authoring data, carried verbatim and consumed at render: [audio] by the
/// audio pipeline and [export] by the export dispatch.
final class Video extends StatefulWidget {
  /// Creates a video of [scenes] on a [size] (or [width] × [height]) canvas
  /// at [fps].
  ///
  /// [scenes] must not be empty — they define the video's duration — and an
  /// explicit [size] preset always wins over the loose dimensions.
  Video({
    required this.scenes,
    this.size,
    int width = 1080,
    int height = 1920,
    this.fps = 30,
    this.motionDefaults,
    this.transition,
    this.audio = const [],
    this.captions,
    this.export,
    this.poster,
    super.key,
  }) : width = size?.width ?? width,
       height = size?.height ?? height {
    if (scenes.isEmpty) {
      throw ArgumentError.value(
        scenes,
        'scenes',
        'A Video needs at least one Scene — the scenes define its duration',
      );
    }
  }

  /// The scenes, played back-to-back in declaration order. Never empty.
  final List<Scene> scenes;

  /// The canvas preset, or `null` when [width]/[height] are given loose.
  final VideoSize? size;

  /// The canvas width in pixels; [size] wins when both are given.
  final int width;

  /// The canvas height in pixels; [size] wins when both are given.
  final int height;

  /// Frames per second of the whole composition.
  final int fps;

  /// Video-level animation defaults — the bottom of the user cascade;
  /// `null` falls through to the package defaults.
  final Defaults? motionDefaults;

  /// The default scene-to-scene blend, or `null` for hard cuts.
  ///
  /// Per-scene `Scene.enter`/`Scene.exit` override it boundary by boundary.
  /// An overlapping transition shortens [totalFrames]; a
  /// sequential one (`overlap: false`) leaves the total unchanged.
  final Transition? transition;

  /// Composition-wide audio tracks — authoring data the audio pipeline mounts
  /// at render.
  final List<Audio> audio;

  /// The caption track, or `null` for none. When set, the shell mounts a
  /// caption layer above the composition that shows the active cue per frame.
  final Captions? captions;

  /// What the render should produce — config data the export pipeline
  /// dispatches on; carried verbatim until then.
  final Export? export;

  /// Which frame is the thumbnail; `null` means frame zero. Lesson goldens
  /// and the inspector read this.
  final Time? poster;

  /// The total length of the video in frames, computed via the shared layout
  /// math: the sum of scene durations minus every overlapping
  /// transition window.
  ///
  /// Throws a `FluvieTimingError` when any scene duration is relative —
  /// a scene's length defines the window relative times
  /// measure against, so it cannot be a fraction of itself — or when a
  /// transition duration is relative (a boundary sits between two scenes).
  int get totalFrames => _offsets.totalFrames;

  /// The frame each scene starts on, in scene order, via the shared layout
  /// math; the first is always `0`. An overlapping transition
  /// starts the next scene early.
  ///
  /// Throws like [totalFrames] on a relative scene or transition duration.
  List<int> get sceneStartFrames => _offsets.startFrames;

  /// The per-boundary transitions after the precedence resolution: each
  /// scene's `enter` beats the previous scene's `exit`, which beats
  /// [transition]. Empty for a single scene; all-cut when nothing governs.
  List<Transition?> get _boundaryTransitions => resolveBoundaryTransitions(
    scenes: [for (final scene in scenes) (enter: scene.enter, exit: scene.exit)],
    videoDefault: transition,
  );

  /// The single source of offset math: scene starts, durations,
  /// and blend windows, resolved against the precedence-collapsed boundaries.
  /// Both the getters above and the [VideoState] shell read this same call, so
  /// the widget tree and the timing resolver can never disagree.
  SceneOffsets get _offsets => resolveSceneOffsets(
    fps: fps,
    durations: [for (final scene in scenes) scene.duration],
    transitions: _boundaryTransitions,
    sceneIds: [for (var s = 0; s < scenes.length; s++) 'scenes[$s]'],
  );

  @override
  State<Video> createState() => VideoState();
}
