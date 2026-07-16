/// @docImport 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
library;

import 'package:flutter/widgets.dart' show Key, Widget;
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/composition/introspection/animation_introspection.dart';
import 'package:fluvie/src/composition/introspection/element_introspection.dart';
import 'package:fluvie/src/composition/introspection/frame_span.dart';
import 'package:fluvie/src/composition/introspection/scene_introspection.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/runtime/video_plan_builder.dart';
import 'package:fluvie/src/composition/transition/boundary_resolver.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';

part 'timeline_introspector.dart';

/// The resolved timeline of a [Video], read statically: ordered scenes with
/// absolute frame bounds, and every animated element's window and animation
/// spans keyed by stable identity.
///
/// Produced by [introspectTimeline] as a pure function of the composition —
/// no widget is mounted, no IO runs, and the same video always introspects
/// identically. It walks the same declared tree fluvie's own collectors walk
/// and resolves it through the same plan pipeline the mounted `Video` uses,
/// so introspection and playback can never disagree.
///
/// ```dart
/// final introspection = introspectTimeline(video);
/// final logoEntrance = introspection.elementForAnchor(logo)!.enterSpan;
/// ```
final class TimelineIntrospection {
  TimelineIntrospection._({
    required this.fps,
    required this.totalFrames,
    required this.scenes,
    required this._byWidget,
  });

  /// Frames per second of the introspected video.
  final int fps;

  /// The video's total length in frames, transition overlaps included.
  final int totalFrames;

  /// The scenes in playback order, each with its absolute bounds and
  /// elements.
  final List<SceneIntrospection> scenes;

  /// Widget-instance identity: both the `.animate()` wrapper and its child
  /// map to the element, so a consumer holding either finds its window.
  final Map<Widget, ElementIntrospection> _byWidget;

  /// Every element across all scenes, in scene then walk order.
  Iterable<ElementIntrospection> get elements => scenes.expand((scene) => scene.elements);

  /// The element declared with [anchor], or `null` when no element carries
  /// that instance. Anchors compare by identity, like everywhere in fluvie.
  ElementIntrospection? elementForAnchor(Anchor anchor) {
    for (final element in elements) {
      if (identical(element.anchor, anchor)) return element;
    }
    return null;
  }

  /// The first element keyed [key] (the `.animate()` wrapper's key or its
  /// child's), or `null` when none is.
  ElementIntrospection? elementForKey(Key key) {
    for (final element in elements) {
      if (element.key == key) return element;
    }
    return null;
  }

  /// The element for a widget instance seen in the declared tree — the
  /// `.animate()` wrapper or its direct child — or `null` for a widget the
  /// walk never met.
  ElementIntrospection? elementFor(Widget widget) => _byWidget[widget];

  /// The elements declared at or below [root], in walk order — the subtree
  /// lookup a consumer uses to find where a wrapped group's entrances sit.
  ///
  /// [root] must be a widget from the introspected composition; an unknown
  /// subtree simply yields no elements.
  List<ElementIntrospection> elementsIn(Widget root) {
    final found = <ElementIntrospection>[];
    walkWidgetTree(root, (widget) {
      if (widget is! MotionTarget) return;
      final element = _byWidget[widget];
      if (element != null) found.add(element);
    });
    return found;
  }

  @override
  String toString() =>
      'TimelineIntrospection(fps: $fps, totalFrames: $totalFrames, '
      'scenes: ${scenes.length})';
}
