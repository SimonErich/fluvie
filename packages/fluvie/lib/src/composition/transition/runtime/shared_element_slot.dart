/// @docImport 'package:fluvie/src/composition/transition/shared_element.dart';
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';

/// The internal render slot a `SharedElement` mounts around its child:
/// a [RenderProxyBox] that records its live box on a
/// [SharedSlotHandle] and skips painting its child while the morph overlay
/// owns its pixels.
///
/// Suppression is decided at **paint** time, never at build: a slot suppresses
/// iff [phase] reports a window active on the boundary it touches **and** the
/// [registry] has a complete pair for its [handle]'s anchor. Deciding at paint
/// removes the build-order race — by paint every slot in both scenes has
/// registered, so the first-painted slot still sees its partner. The flag is a
/// pure paint skip (`markNeedsPaint` only), so the child keeps its Element,
/// State, and nested registrations while the overlay clone takes over.
final class SharedElementSlot extends SingleChildRenderObjectWidget {
  /// Wraps [child], recording its box on [handle]; suppression is computed at
  /// paint from [phase] and [registry] against this slot's [sceneIndex].
  const SharedElementSlot({
    required this.handle,
    required this.registry,
    required this.sceneIndex,
    required this.phase,
    required Widget super.child,
    super.key,
  });

  /// The handle whose [SharedSlotHandle.box] this slot keeps in sync.
  final SharedSlotHandle handle;

  /// The composition's registry, consulted for a complete pair at paint.
  final SharedElementRegistry registry;

  /// The index of the scene this slot lives in.
  final int sceneIndex;

  /// The active blend window over this scene, or `null` outside one.
  final TransitionPhase? phase;

  @override
  RenderSharedElementSlot createRenderObject(BuildContext context) => RenderSharedElementSlot(
    handle: handle,
    registry: registry,
    sceneIndex: sceneIndex,
    phase: phase,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSharedElementSlot renderObject) =>
      renderObject
        ..handle = handle
        ..registry = registry
        ..sceneIndex = sceneIndex
        ..phase = phase;
}

/// The render object behind [SharedElementSlot].
final class RenderSharedElementSlot extends RenderProxyBox {
  /// Creates a slot render box recording itself on [handle].
  RenderSharedElementSlot({
    required SharedSlotHandle handle,
    required SharedElementRegistry registry,
    required int sceneIndex,
    required TransitionPhase? phase,
  }) {
    // Assigned in the body (not as initializing formals): the private fields
    // back getter/setter pairs whose setters run box-pointer and paint side
    // effects, so they cannot be reached by a `this._field` formal.
    _handle = handle;
    _registry = registry;
    _sceneIndex = sceneIndex;
    _phase = phase;
  }

  late SharedSlotHandle _handle;
  late SharedElementRegistry _registry;
  late int _sceneIndex;
  late TransitionPhase? _phase;

  /// The handle whose box this render object publishes; reassigning it moves
  /// the live-box pointer to the new handle.
  SharedSlotHandle get handle => _handle;
  set handle(SharedSlotHandle value) {
    if (identical(_handle, value)) return;
    if (attached && _handle.box == this) _handle.box = null;
    _handle = value;
    if (attached) _handle.box = this;
  }

  /// The registry consulted for a complete pair at paint.
  SharedElementRegistry get registry => _registry;
  set registry(SharedElementRegistry value) {
    if (identical(_registry, value)) return;
    _registry = value;
    markNeedsPaint();
  }

  /// The index of the scene this slot lives in.
  int get sceneIndex => _sceneIndex;
  set sceneIndex(int value) {
    if (_sceneIndex == value) return;
    _sceneIndex = value;
    markNeedsPaint();
  }

  /// The active blend window over this scene, or `null` outside one.
  TransitionPhase? get phase => _phase;
  set phase(TransitionPhase? value) {
    if (_phase == value) return;
    _phase = value;
    markNeedsPaint();
  }

  /// Whether the morph overlay owns this slot's pixels this frame — a window
  /// is active on the boundary this slot touches and its anchor has a complete
  /// pair.
  bool get suppress {
    final phase = _phase;
    if (phase == null) return false;
    final asSource = phase.boundary == _sceneIndex;
    final asTarget = phase.boundary == _sceneIndex - 1;
    if (!asSource && !asTarget) return false;
    final pair = _registry.pairAtBoundary(phase.boundary);
    return pair != null && identical(pair.anchor, _handle.anchor);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle.box = this;
  }

  @override
  void detach() {
    if (_handle.box == this) _handle.box = null;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (suppress) return;
    super.paint(context, offset);
  }
}
