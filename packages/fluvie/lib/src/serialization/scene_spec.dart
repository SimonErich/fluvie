import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/audio_track_spec.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/clip_lane_mix.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/element_transition_builder.dart';
import 'package:fluvie/src/serialization/element_transition_spec.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';

part 'scene_spec_fills.dart';
part 'scene_layout.dart';
part 'scene_spec_parser.dart';
part 'scene_step_specs.dart';

/// The data form of a [Scene]: its `duration`, optional `background`, the
/// `layout` mode, the scene-scoped `audio` tracks, the `children`, optional
/// `enter`/`exit` transitions, optional `motionDefaults`, the
/// presentation-only `steps` and `notes`, and the optional adopted [master]
/// with its slot [fills].
final class SceneSpec {
  /// Creates a scene spec lasting [duration] with the given parts.
  SceneSpec({
    required this.duration,
    this.background,
    this.layout = SceneLayout.stack,
    this.master,
    this.fills = const {},
    this.audio = const [],
    this.children = const [],
    this.enter,
    this.exit,
    this.motionDefaults,
    this.steps = const [],
    this.notes,
    this.transitions = const [],
  });

  /// Reads a scene spec from [json], resolving anchors through [anchors].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing `duration` or
  /// a malformed `children` list.
  factory SceneSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) => _parseSceneSpec(json, anchors, path: path);

  /// The keys a scene object reads. The single source of truth for the
  /// per-scene unknown-property check; it must stay in step with the keys
  /// [SceneSpec.fromJson] consumes.
  static const Set<String> knownKeys = {
    'duration',
    'background',
    'layout',
    'master',
    'fills',
    'audio',
    'children',
    'enter',
    'exit',
    'motionDefaults',
    'steps',
    'notes',
    'transitions',
  };

  /// How long the scene lasts.
  final Time duration;

  /// The static backdrop, or null for none.
  final BackgroundSpec? background;

  /// How children arrange themselves; [SceneLayout.stack] unless declared.
  final SceneLayout layout;

  /// The name of the master layout this scene adopts, or null for a fully
  /// freeform scene. Applied at build time by `resolveSceneMaster` — the
  /// document itself stays unresolved, so editing the master changes every
  /// adopting scene with no copies.
  final String? master;

  /// The elements filling the [master]'s named slots, keyed by slot name.
  /// A fill is a scene-owned element (it carries its own `id`); its
  /// `transform`, when present, overrides the placeholder's.
  final Map<String, ElementSpec> fills;

  /// The audio tracks scoped to this scene, starting with it; empty for a
  /// silent scene. Engine-consumed: [build] hands them to `Scene.audio`, so
  /// the audio collector and the amix plan read them unchanged.
  final List<AudioTrackSpec> audio;

  /// The scene's children.
  final List<ElementSpec> children;

  /// Clip-level blends, resolved inside their scene/group holding list.
  final List<ElementTransitionSpec> transitions;

  /// The transition this scene enters across, or null.
  final Transition? enter;

  /// The transition this scene exits across, or null.
  final Transition? exit;

  /// Scene-level animation defaults, or null to inherit.
  final Defaults? motionDefaults;

  /// The ordered build steps, presentation metadata over [children]; empty
  /// when the scene plays straight through (see [StepSpec]).
  final List<StepSpec> steps;

  /// The scene's default speaker notes, or null for none (see [NotesSpec]).
  final NotesSpec? notes;

  /// The JSON form of this scene.
  Map<String, Object?> toJson() => {
    'duration': encodeTime(duration),
    if (audio.isNotEmpty) 'audio': [for (final track in audio) track.toJson()],
    if (background != null) 'background': background!.toJson(),
    if (layout != SceneLayout.stack) 'layout': layout.name,
    if (master != null) 'master': master,
    if (fills.isNotEmpty)
      'fills': {for (final entry in fills.entries) entry.key: entry.value.toJson()},
    if (children.isNotEmpty) 'children': [for (final child in children) child.toJson()],
    if (transitions.isNotEmpty)
      'transitions': [for (final transition in transitions) transition.toJson()],
    if (steps.isNotEmpty) 'steps': [for (final step in steps) step.toJson()],
    if (notes != null) 'notes': notes!.toJson(),
    if (enter != null) 'enter': encodeTransition(enter!),
    if (exit != null) 'exit': encodeTransition(exit!),
    if (motionDefaults != null) 'motionDefaults': encodeDefaults(motionDefaults!),
  };

  /// Builds the real [Scene], resolving anchors through [anchors].
  ///
  /// [steps] and [notes] are deliberately ignored: they are presentation
  /// metadata the engine never reads, so a rendered video plays straight
  /// through. Only `package:fluvie_presenter` interprets them. [master] and
  /// [fills] are ignored too: an adopting scene resolves through
  /// `resolveSceneMaster` first (`VideoSpec.build` does), and the resolved
  /// scene is what builds.
  Scene build(
    AnchorTable anchors, {
    Set<String> mutedLaneIds = const {},
    int fps = 30,
    Map<String, double> laneGains = const {},
  }) => Scene(
    duration: duration,
    background: background?.build(),
    enter: enter,
    exit: exit,
    motionDefaults: motionDefaults,
    audio: [
      for (final track in audio)
        if (!mutedLaneIds.contains(track.lane)) track.build(laneGain: laneGains[track.lane] ?? 1),
    ],
    children: buildElementTransitions(
      [
        for (final child in children)
          applyClipLaneMix(child, anchors, mutedLaneIds: mutedLaneIds, laneGains: laneGains),
      ],
      transitions,
      anchors,
      fps: fps,
      durationFrames: resolveSceneDurationFrames(duration, fps, 'scene'),
    ),
  );
}

Map<String, Object?> _object(Object? raw, List<String> path) {
  if (raw is Map<String, Object?>) return raw;
  throw FluvieSpecError('Expected an object', path: path);
}

List<ElementTransitionSpec> _decodeElementTransitions(Object? raw, List<String> path) {
  if (raw == null) return const [];
  if (raw is! List) throw FluvieSpecError('Expected a transitions list', path: path);
  return [
    for (var i = 0; i < raw.length; i++)
      ElementTransitionSpec.fromJson(_object(raw[i], [...path, '$i']), path: [...path, '$i']),
  ];
}
