import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_slot.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';
import 'package:fluvie/src/core/anchor.dart';

/// A shared-element ("hero") slot: the same [child] in two
/// adjacent scenes, tied together by one [anchor], morphs across the
/// transition between them.
///
/// Place a `SharedElement` with the **same [Anchor] instance** in both
/// adjacent scenes (equality is identity, so two `Anchor('logo')` never pair):
///
/// ```dart
/// final logo = Anchor('logo');
/// // scene 1: large, centred
/// SharedElement(anchor: logo, child: Box(color: brand, size: Size(0.4, 0.4)))
/// // scene 2: small, top-left
/// SharedElement(anchor: logo, child: Box(color: brand, size: Size(0.1, 0.1)))
/// ```
///
/// During the boundary's blend window the destination (incoming) child is
/// painted by an overlay above both scenes, travelling from the source rect to
/// the target rect; the rects are read live off the mounted scenes, so the
/// morph follows any `Camera` on either scene. Each slot's opacity tracks its
/// enclosing keyframe, so `SharedElement(...).animate([Animation.fadeOut()])`
/// morphs honestly.
///
/// Outside a `Video`/`Scene` (no [SharedElementScope] above), a `SharedElement`
/// is a transparent passthrough of [child] — the same standalone path a
/// `MotionTarget` takes. Keep a shared child's animations self-contained: the
/// overlay clone resolves standalone, so a cross-element trigger inside it
/// raises the documented guidance error.
///
/// Wrap an element in a `SharedElement` yourself to make it shared.
final class SharedElement extends StatefulWidget {
  /// Creates a shared slot tying [child] to [anchor] across one boundary.
  const SharedElement({required this.anchor, required this.child, super.key});

  /// The shared anchor; the same instance must appear in both adjacent scenes.
  /// `null` makes this a plain passthrough (no hero), useful for a child that
  /// is shared in one configuration but not another.
  final Anchor? anchor;

  /// The element that morphs across the boundary.
  final Widget child;

  @override
  State<SharedElement> createState() => _SharedElementState();
}

final class _SharedElementState extends State<SharedElement> {
  SharedSlotHandle? _handle;
  SharedElementRegistry? _registry;

  @override
  void dispose() {
    _delist();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SharedElementScope.maybeOf(context);
    final anchor = widget.anchor;
    // Standalone: no scope or no anchor — pass the child straight through, the
    // documented MotionTarget-standalone behaviour.
    if (scope == null || anchor == null) {
      _delist();
      return widget.child;
    }
    _ensureHandle(scope.registry, anchor, scope.sceneIndex);
    // Refresh the live opacity from the enclosing keyframe every build; the
    // slot's render object decides suppression at paint, so the
    // first-painted partner still sees the pair the other registered.
    return SharedElementSlot(
      handle: _handle!..opacity = KeyframeScope.maybeOf(context)?.opacity ?? 1.0,
      registry: scope.registry,
      sceneIndex: scope.sceneIndex,
      phase: TransitionPhaseScope.maybeOf(context),
      child: widget.child,
    );
  }

  void _ensureHandle(SharedElementRegistry registry, Anchor anchor, int sceneIndex) {
    final current = _handle;
    if (current != null &&
        identical(_registry, registry) &&
        identical(current.anchor, anchor) &&
        current.sceneIndex == sceneIndex) {
      return;
    }
    _delist();
    _handle = SharedSlotHandle(anchor: anchor, sceneIndex: sceneIndex, child: widget.child);
    _registry = registry;
    registry.register(_handle!);
  }

  void _delist() {
    final handle = _handle;
    final registry = _registry;
    if (handle != null && registry != null) registry.unregister(handle);
    _handle = null;
    _registry = null;
  }
}
