import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/relative_duration_guard.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

part 'element_transition_window.dart';
part 'element_transition_layout.dart';
part 'element_transition_resolver.dart';

/// A scene-local transition between two consecutive clips on one lane.
/// The authored windows remain unchanged; their resolved overlap is derived
/// through the same offset resolver that places scenes.
final class ElementTransitionSpec {
  /// Blends [outgoing] into [incoming] through [transition].
  const ElementTransitionSpec({
    required this.outgoing,
    required this.incoming,
    required this.transition,
  });

  /// Parses the `between: [outgoing, incoming]` pair and transition fields.
  factory ElementTransitionSpec.fromJson(
    Map<String, Object?> json, {
    List<String> path = const [],
  }) {
    final pair = json['between'];
    if (pair is! List ||
        pair.length != 2 ||
        pair.any((id) => id is! String || id.isEmpty) ||
        pair[0] == pair[1]) {
      throw FluvieSpecError(
        'A clip transition needs two distinct element ids in "between"',
        path: [...path, 'between'],
      );
    }
    final raw = {...json}..remove('between');
    final transition = decodeTransition(raw, path: path);
    if (transition.kind == TransitionKind.cut) {
      throw FluvieSpecError('A cut needs no clip transition', path: path);
    }
    return ElementTransitionSpec(
      outgoing: pair[0]! as String,
      incoming: pair[1]! as String,
      transition: transition,
    );
  }

  /// The outgoing clip's stable element id.
  final String outgoing;

  /// The incoming clip's stable element id.
  final String incoming;

  /// The shared scene/element strategy vocabulary.
  final Transition transition;

  /// The canonical additive scene-level representation.
  Map<String, Object?> toJson() => {
    'between': [outgoing, incoming],
    ...encodeTransition(transition),
  };
}

/// Widget-independent inputs for the shared native/spec transition planner.
final class ClipTransitionElement {
  /// Describes a sibling's authored clock window and lane.
  const ClipTransitionElement({
    required this.id,
    required this.isClip,
    this.lane,
    this.window,
    this.shared = false,
  });

  /// Stable sibling identity.
  final String? id;

  /// Whether the sibling is a clip transition target.
  final bool isClip;

  /// Optional lane identity.
  final String? lane;

  /// Authored window in the parent clock.
  final TimeRange? window;

  /// Shared heroes use scene transitions instead of clip transitions.
  final bool shared;
}
