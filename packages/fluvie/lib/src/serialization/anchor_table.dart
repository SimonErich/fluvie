import 'package:fluvie/src/core/anchor.dart';

/// Mints one canonical [Anchor] per string id for a single spec document.
///
/// In a `VideoSpec` an anchor is just a name, but the timing resolver keys its
/// dependency graph by [Anchor] *identity* (see [Anchor]). This table
/// guarantees that every reference to the same id — the element that declares
/// it and every `Trigger.whenEnds`/`Trigger.whenStarts`/`Audio.track` that points
/// at it — resolves to the **same** [Anchor] instance, so identity survives
/// serialization.
final class AnchorTable {
  /// Creates an empty table; anchors are minted lazily by [resolve].
  AnchorTable();

  final Map<String, Anchor> _byId = {};

  /// The canonical anchor for [id], created (named [id]) the first time the id
  /// is seen and returned unchanged thereafter.
  Anchor resolve(String id) => _byId.putIfAbsent(id, () => Anchor(id));

  /// The ids resolved so far, in first-seen order.
  Iterable<String> get ids => _byId.keys;
}
