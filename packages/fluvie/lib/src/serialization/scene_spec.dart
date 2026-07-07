import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// The data form of a [Scene]: its `duration`, optional `background`, the
/// `children`, optional `enter`/`exit` transitions, and optional
/// `motionDefaults`.
final class SceneSpec {
  /// Creates a scene spec lasting [duration] with the given parts.
  SceneSpec({
    required this.duration,
    this.background,
    this.children = const [],
    this.enter,
    this.exit,
    this.motionDefaults,
  });

  /// Reads a scene spec from [json], resolving anchors through [anchors].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing `duration` or
  /// a malformed `children` list.
  factory SceneSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) {
    final durationRaw = json['duration'];
    if (durationRaw == null) {
      throw FluvieSpecError('A scene needs a "duration"', path: path);
    }
    final children = <ElementSpec>[];
    final childrenRaw = json['children'];
    if (childrenRaw is List) {
      for (var i = 0; i < childrenRaw.length; i++) {
        final child = childrenRaw[i];
        if (child is! Map<String, Object?>) {
          throw FluvieSpecError('Expected an element object', path: [...path, 'children', '$i']);
        }
        children.add(ElementSpec.fromJson(child, anchors, path: [...path, 'children', '$i']));
      }
    } else if (childrenRaw != null) {
      throw FluvieSpecError('Expected "children" to be a list', path: [...path, 'children']);
    }
    final background = json['background'];
    final enter = json['enter'];
    final exit = json['exit'];
    final motion = json['motionDefaults'];
    return SceneSpec(
      duration: decodeTime(durationRaw, path: [...path, 'duration']),
      background: background == null
          ? null
          : BackgroundSpec.fromJson(
              _object(background, [...path, 'background']),
              path: [...path, 'background'],
            ),
      children: children,
      enter: enter == null ? null : decodeTransition(enter, path: [...path, 'enter']),
      exit: exit == null ? null : decodeTransition(exit, path: [...path, 'exit']),
      motionDefaults: motion == null
          ? null
          : decodeDefaults(motion, path: [...path, 'motionDefaults']),
    );
  }

  /// The keys a scene object reads. The single source of truth for the
  /// per-scene unknown-property check; it must stay in step with the keys
  /// [SceneSpec.fromJson] consumes.
  static const Set<String> knownKeys = {
    'duration',
    'background',
    'children',
    'enter',
    'exit',
    'motionDefaults',
  };

  /// How long the scene lasts.
  final Time duration;

  /// The static backdrop, or null for none.
  final BackgroundSpec? background;

  /// The scene's children.
  final List<ElementSpec> children;

  /// The transition this scene enters across, or null.
  final Transition? enter;

  /// The transition this scene exits across, or null.
  final Transition? exit;

  /// Scene-level animation defaults, or null to inherit.
  final Defaults? motionDefaults;

  /// The JSON form of this scene.
  Map<String, Object?> toJson() => {
    'duration': encodeTime(duration),
    if (background != null) 'background': background!.toJson(),
    if (children.isNotEmpty) 'children': [for (final child in children) child.toJson()],
    if (enter != null) 'enter': encodeTransition(enter!),
    if (exit != null) 'exit': encodeTransition(exit!),
    if (motionDefaults != null) 'motionDefaults': encodeDefaults(motionDefaults!),
  };

  /// Builds the real [Scene], resolving anchors through [anchors].
  Scene build(AnchorTable anchors) => Scene(
    duration: duration,
    background: background?.build(),
    enter: enter,
    exit: exit,
    motionDefaults: motionDefaults,
    children: [for (final child in children) child.build(anchors)],
  );
}

Map<String, Object?> _object(Object? raw, List<String> path) {
  if (raw is Map<String, Object?>) return raw;
  throw FluvieSpecError('Expected an object', path: path);
}
