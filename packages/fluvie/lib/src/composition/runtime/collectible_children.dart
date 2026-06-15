import 'package:flutter/widgets.dart' show Widget;

/// A widget that holds declared child widgets the media collectors must descend
/// into.
///
/// `collectMediaSources` / `collectSnapshotSources` walk the declared tree by
/// shape: they see Flutter's render-object widgets (`SingleChildRenderObjectWidget`,
/// `MultiChildRenderObjectWidget`), `ProxyWidget`s, and `MotionTarget` and recurse
/// into their children, but never mount or build anything. A Fluvie wrapper that
/// is a plain `StatelessWidget` (it builds its children inside `build`, e.g.
/// `DeviceFrame`, `Frame`, `Snapshot`) is otherwise opaque to that walk, so a
/// `MediaCarrier` nested inside it would be missed and never pre-resolved before
/// frame 0 (it would then throw at capture). Such wrappers implement this so the
/// collectors descend into [collectibleChildren] without building anything.
abstract interface class CollectibleChildren {
  /// The declared children the media collectors descend into. Read structurally
  /// (never built or mounted), so it must return the wrapper's own constructor
  /// children, not anything computed in `build`.
  Iterable<Widget> get collectibleChildren;
}
