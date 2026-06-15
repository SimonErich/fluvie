/// @docImport 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
/// @docImport 'package:fluvie/src/composition/transition/shared_element.dart';
library;

import 'package:flutter/widgets.dart' show RenderBox, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

/// One registered `SharedElement` slot: the identity token a
/// `SharedElement` builds once and hands to its enclosing
/// [SharedElementRegistry].
///
/// The handle carries authoring data ([anchor], [sceneIndex], the morph
/// [child]) and two fields the live render tree fills in per frame: [box] is
/// the slot's mounted [RenderBox] (used by the morph layer to read the live
/// rect, never cached across frames), and [opacity] mirrors the slot's
/// enclosing keyframe opacity so a faded shared element morphs honestly.
final class SharedSlotHandle {
  /// Creates a slot handle for [anchor] in scene [sceneIndex] carrying the
  /// morph [child]; [box] and [opacity] are filled in by the live render tree.
  SharedSlotHandle({
    required this.anchor,
    required this.sceneIndex,
    required this.child,
    this.box,
    this.opacity = 1,
  });

  /// The shared anchor; the same instance must appear in both adjacent scenes
  /// (equality is identity, so distinct `Anchor`s never pair).
  final Anchor anchor;

  /// Which scene this slot lives in.
  final int sceneIndex;

  /// The widget the morph layer paints (destination wins, so the incoming
  /// slot's child is the one that travels).
  final Widget child;

  /// The slot's mounted box, or `null` while it is unmounted; the morph layer
  /// reads its rect live at paint time.
  RenderBox? box;

  /// The slot's enclosing keyframe opacity, refreshed per build; the morph
  /// lerps source-to-target opacity from the two slots' values.
  double opacity;
}

/// A matched pair of slots across one boundary: the `source` (outgoing scene)
/// and the `target` (incoming scene) sharing one `anchor`.
typedef SharedPair = ({Anchor anchor, SharedSlotHandle source, SharedSlotHandle target});

/// The per-collect-generation registry of `SharedElement` slots.
///
/// `Video` owns one per collect generation and provides it down each scene
/// shell via a `SharedElementScope`. Slots register on mount and delist on
/// dispose; [validate] runs in the post-frame resolve pass (before any
/// captured frame) and throws the three validation errors for a malformed
/// anchor set. After validation the slot set is stable: a *new* anchor registering
/// throws (mirroring the resolver's stable-token rule), while unregister and
/// re-register of an already-known anchor merely delists and relists.
final class SharedElementRegistry {
  final List<SharedSlotHandle> _handles = [];
  bool _validated = false;

  /// Whether [validate] has run for this generation.
  bool get isValidated => _validated;

  /// Registers [handle]. After [validate] a slot whose anchor is not already
  /// known throws a [FluvieTimingError] (the stable-set rule).
  void register(SharedSlotHandle handle) {
    if (_validated && !_handles.any((h) => identical(h.anchor, handle.anchor))) {
      throw FluvieTimingError(
        'A shared element registered after the plan was resolved. Shared '
        'anchors must be declared during the first build, like every other '
        'timed element — a late SharedElement cannot join the morph set.',
        anchors: [handle.anchor],
      );
    }
    _handles.add(handle);
  }

  /// Delists [handle] (on dispose). Never throws: a tear-down may run at any
  /// time, including after validation.
  void unregister(SharedSlotHandle handle) => _handles.remove(handle);

  /// The complete pair across [boundary] (between scenes `boundary` and
  /// `boundary + 1`), or `null` when no anchor has a slot in both.
  SharedPair? pairAtBoundary(int boundary) {
    for (final anchor in _anchors()) {
      final scenes = _scenesOf(anchor);
      if (scenes.length != 2) continue;
      final lower = scenes.reduce((a, b) => a < b ? a : b);
      if (lower != boundary || !scenes.contains(lower + 1)) continue;
      return (
        anchor: anchor,
        source: _slotIn(anchor, lower),
        target: _slotIn(anchor, lower + 1),
      );
    }
    return null;
  }

  /// Validates the whole slot set against the [sceneCount],
  /// then marks the set stable. Throws a [FluvieTimingError] for an anchor in
  /// one scene, in three or more scenes, or in two non-adjacent scenes. Two
  /// adjacent scenes are valid whether their boundary is timed or a cut — a
  /// cut boundary opens a zero-frame window, so the pair is simply inert (no
  /// morph), which lets transitions toggle without restructuring the scenes.
  void validate(int sceneCount) {
    for (final anchor in _anchors()) {
      _validateAnchor(anchor, _scenesOf(anchor), sceneCount);
    }
    _validated = true;
  }

  /// Clears every registration and the validated flag — called when the
  /// owning `Video` resets its collect generation.
  void reset() {
    _handles.clear();
    _validated = false;
  }

  void _validateAnchor(Anchor anchor, List<int> scenes, int sceneCount) {
    final name = anchor.debugName ?? 'Anchor#${identityHashCode(anchor)}';
    final where = scenes.map((s) => "'scenes[$s]'").join(', ');
    assert(
      scenes.every((s) => s >= 0 && s < sceneCount),
      // coverage:ignore-line: defensive assert message; slots always register a valid scene index
      'a shared slot named a scene index outside [0, $sceneCount)',
    );
    if (scenes.length == 1) {
      throw FluvieTimingError(
        'The shared element "$name" appears in one scene ($where). A hero '
        'morphs between two scenes — add the matching SharedElement to the '
        'adjacent scene or drop shared.',
        anchors: [anchor],
      );
    }
    if (scenes.length >= 3) {
      throw FluvieTimingError(
        'The shared element "$name" appears in $where — a hero morphs across '
        'one boundary, so it may belong to at most two adjacent scenes.',
        anchors: [anchor],
      );
    }
    final lower = scenes.first < scenes.last ? scenes.first : scenes.last;
    final upper = scenes.first < scenes.last ? scenes.last : scenes.first;
    if (upper - lower != 1) {
      throw FluvieTimingError(
        'The shared element "$name" spans non-adjacent scenes ($where). '
        'Heroes morph across one boundary — put the pair in neighbouring '
        'scenes.',
        anchors: [anchor],
      );
    }
  }

  Iterable<Anchor> _anchors() {
    final seen = <Anchor>[];
    for (final handle in _handles) {
      if (!seen.any((a) => identical(a, handle.anchor))) seen.add(handle.anchor);
    }
    return seen;
  }

  List<int> _scenesOf(Anchor anchor) {
    final scenes = <int>[];
    for (final handle in _handles) {
      if (identical(handle.anchor, anchor) && !scenes.contains(handle.sceneIndex)) {
        scenes.add(handle.sceneIndex);
      }
    }
    scenes.sort();
    return scenes;
  }

  SharedSlotHandle _slotIn(Anchor anchor, int sceneIndex) => _handles.firstWhere(
    (h) => identical(h.anchor, anchor) && h.sceneIndex == sceneIndex,
  );
}
