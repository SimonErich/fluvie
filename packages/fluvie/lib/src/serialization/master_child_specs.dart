part of 'master_spec.dart';

/// One entry of a master's `children` list: fixed chrome or a named slot.
sealed class MasterChildSpec {
  /// The JSON form of this child.
  Map<String, Object?> toJson();
}

/// A fixed chrome child of a master: a full element (logo, footer, frame)
/// rendered identically under every adopting scene. It carries no identity
/// keys; the editor edits it in master-edit mode, not per scene.
final class MasterElementSpec extends MasterChildSpec {
  /// Wraps the fixed [element].
  MasterElementSpec(this.element);

  /// The element this child renders.
  final ElementSpec element;

  @override
  Map<String, Object?> toJson() => element.toJson();
}

/// A named slot inside a master: where a scene's fill lands ([placement]),
/// plus optional presentation defaults ([style]) merged *under* the fill's
/// own style per field. Legal only inside master definitions.
final class PlaceholderSpec extends MasterChildSpec {
  /// Creates a slot named [slot] with an optional [placement] and [style].
  PlaceholderSpec({required this.slot, this.placement, this.style});

  /// The slot name a scene's `fills` key refers to.
  final String slot;

  /// Where the fill lands, unless the fill carries its own `transform` (the
  /// scene-level override, which wins).
  final Placement? placement;

  /// Style defaults for the fill, merged under the fill's own `style` per
  /// field (the fill wins). A fill whose type reads no style ignores them.
  final Map<String, Object?>? style;

  @override
  Map<String, Object?> toJson() => {
    'type': 'Placeholder',
    'slot': slot,
    if (placement != null) 'transform': encodePlacement(placement!),
    if (style != null) 'style': {...style!},
  };
}
