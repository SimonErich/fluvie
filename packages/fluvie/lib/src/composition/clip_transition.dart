import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/runtime/clip_transition_audio.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/runtime/element_transition_stack.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/runtime/spec_element_id.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart' as fluvie;
import 'package:fluvie/src/serialization/element_transition_spec.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A pair of clip ids blended with the same strategies as scene transitions.
typedef ClipTransition = ElementTransitionSpec;

/// Pairs identified siblings without converting readable Flutter code to specs.
///
/// Wrap each target in ElementId and put its show/animate window directly
/// inside the marker. Windows may abut or overlap; the shared planner derives
/// effective overlaps and the matching equal-power embedded-audio envelope.
final class ClipTransitionGroup extends StatelessWidget implements CollectibleChildren {
  /// Composes [transitions] between identified [children] in a shared clock.
  const ClipTransitionGroup({required this.children, required this.transitions, super.key});

  /// Siblings retain declaration order, including unrelated overlay widgets.
  final List<Widget> children;

  /// Each edge names two consecutive clips on the same lane.
  final List<ClipTransition> transitions;
  @override
  Iterable<Widget> get collectibleChildren => children;

  /// Resolves the native widget tree through the same neutral planner as specs.
  ElementTransitionStack resolve(TimeScopeData scope) {
    final elements = <ClipTransitionElement>[];
    final seen = <String>{};
    for (final child in children) {
      if (child is! ElementId) {
        elements.add(const ClipTransitionElement(id: null, isClip: false));
        continue;
      }
      if (child.id.isEmpty || !seen.add(child.id)) {
        throw FluvieTimingError(
          'ClipTransitionGroup needs nonempty, unique ElementId values; duplicate "${child.id}".',
        );
      }
      final target = child.child;
      fluvie.Clip? clip;
      walkWidgetTree(target, (widget) {
        if (widget is fluvie.Clip) clip ??= widget;
      });
      // Opaque Flutter custom components are mounted normally. Their outer
      // authored window remains available even when their Clip is built later.
      final opaque = declaredChildren(target is MotionTarget ? target.child : target).isEmpty;
      elements.add(
        ClipTransitionElement(
          id: child.id,
          lane: child.lane,
          window: target is MotionTarget ? target.window : null,
          isClip: clip != null || opaque,
          shared: clip?.shared != null,
        ),
      );
    }
    late final ElementTransitionLayout layout;
    try {
      layout = resolveClipTransitionLayout(
        children: elements,
        transitions: transitions,
        fps: scope.fps,
        durationFrames: scope.durationFrames,
      );
    } on FluvieSpecError catch (error) {
      throw FluvieTimingError(error.message);
    }
    final resolved = <Widget>[];
    for (final child in children) {
      if (child is! ElementId || !layout.windows.containsKey(child.id)) {
        resolved.add(child);
        continue;
      }
      final window = layout.windows[child.id]!;
      final blends = layout.blends
          .where((edge) => edge.outgoing == child.id || edge.incoming == child.id)
          .toList();
      final target = child.child;
      final audio = ClipTransitionAudioScope(
        id: child.id,
        window: window,
        blends: blends,
        fps: scope.fps,
        child: target is MotionTarget ? target.child : target,
      );
      final animated = MotionTarget(
        animations: target is MotionTarget ? target.animations : const [],
        anchor: target is MotionTarget ? target.anchor : null,
        defaults: target is MotionTarget ? target.defaults : null,
        window: Time.frames(window.start).to(Time.frames(window.end)),
        key: target is MotionTarget ? target.key : null,
        child: audio,
      );
      resolved.add(ElementId(id: child.id, lane: child.lane, key: child.key, child: animated));
    }
    return ElementTransitionStack(
      ids: [
        for (final child in children)
          if (child is ElementId) child.id else null,
      ],
      blends: layout.blends,
      children: resolved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stack = resolve(TimeScopeProvider.of(context));
    return stack;
  }
}
