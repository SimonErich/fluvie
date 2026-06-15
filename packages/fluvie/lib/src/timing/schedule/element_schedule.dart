/// @docImport 'package:fluvie/src/timing/placement/effective_duration.dart';
/// @docImport 'package:fluvie/src/timing/resolver/composition_resolver.dart';
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:meta/meta.dart';

/// Everything one element's animations need at render time: its resolved
/// [window], the resolved [spans] of its animations, and the fully-merged
/// [defaults] cascade.
///
/// [spans] is **index-aligned with the element's animations list**: the span
/// at index `i` belongs to the `i`-th declared animation, so a consumer must
/// never reorder either list. Under `Video` the registrar injects the
/// schedule; outside any composition `MotionTarget` self-resolves a local one
/// (the documented standalone mode).
@immutable
final class ElementSchedule {
  /// Creates a schedule; [spans] must align index-by-index with the
  /// animations it was resolved from.
  const ElementSchedule({required this.window, required this.spans, required this.defaults});

  /// The element's alive-window in absolute video frames.
  final ResolvedSpan window;

  /// One resolved span per animation, in declaration order.
  final List<ResolvedSpan> spans;

  /// The merged [Defaults] cascade for this element — element over scene over
  /// video over package — so ease/duration/stagger inheritance survives the
  /// schedule being injected from outside.
  final Defaults defaults;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElementSchedule &&
          other.window == window &&
          listEquals(other.spans, spans) &&
          other.defaults == defaults;

  @override
  int get hashCode => Object.hash(ElementSchedule, window, Object.hashAll(spans), defaults);

  @override
  String toString() => 'ElementSchedule(window: $window, spans: $spans, defaults: $defaults)';
}
