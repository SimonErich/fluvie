import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/placement.dart';

/// Per-element [Placement] replacements, applied while an editing tool drags
/// elements around the canvas.
///
/// A canvas editor mounts this scope over a built composition and updates
/// [overrides] as the pointer moves; each identified `Placed` element reads
/// its own entry and re-lays out, while the document — and every untouched
/// element — stays exactly as built. On release the editor writes the real
/// `transform` mutation and clears the scope.
///
/// The scope is an [InheritedModel] keyed by element id, so an update only
/// rebuilds the elements whose entry actually changed — the transform-only
/// fast path a drag needs.
final class PlacedOverrides extends InheritedModel<String> {
  /// Mounts [overrides] over [child].
  const PlacedOverrides({required this.overrides, required super.child, super.key});

  /// Placement replacements by element id.
  final Map<String, Placement> overrides;

  /// The override for [id], or null when it has none. Subscribes the caller
  /// to changes of [id]'s entry alone.
  static Placement? of(BuildContext context, String id) =>
      InheritedModel.inheritFrom<PlacedOverrides>(context, aspect: id)?.overrides[id];

  @override
  bool updateShouldNotify(PlacedOverrides oldWidget) => !mapEquals(overrides, oldWidget.overrides);

  @override
  bool updateShouldNotifyDependent(PlacedOverrides oldWidget, Set<String> dependencies) =>
      dependencies.any((id) => overrides[id] != oldWidget.overrides[id]);
}
