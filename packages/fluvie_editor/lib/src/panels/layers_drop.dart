/// One row of the flattened layers list, topmost first: the element, the
/// group holding it (null at the top level), whether it is a Group, and —
/// for groups — whether its subtree is open in the panel.
typedef LayerRowEntry = ({String id, String? parent, bool isGroup, bool expanded});

/// What one drop in the flattened layers list means, expressed in document
/// z-indices ready for the commands.
sealed class LayersDropPlan {
  const LayersDropPlan();
}

/// A plain z-reorder within the row's own holding list.
final class LayersReorder extends LayersDropPlan {
  /// Moves [id] to z-position [to] in its holding list.
  const LayersReorder(this.id, this.to);

  /// The reordered element.
  final String id;

  /// The target z-position (post-removal insert index).
  final int to;
}

/// A move into [group] at child z-position [at].
final class LayersMoveIn extends LayersDropPlan {
  /// Moves [id] into [group] at child slot [at].
  const LayersMoveIn(this.id, this.group, this.at);

  /// The moved element.
  final String id;

  /// The receiving group.
  final String group;

  /// The child z-position.
  final int at;
}

/// A promotion out of [group] to top-level z-position [at].
final class LayersMoveOut extends LayersDropPlan {
  /// Moves [id] out of [group] to top-level slot [at].
  const LayersMoveOut(this.id, this.group, this.at);

  /// The promoted child.
  final String id;

  /// The group being left.
  final String group;

  /// The top-level z-position.
  final int at;
}

/// Interprets one drop of the flattened layers list — [from] and [to] as
/// `OiReorderable` reports them (the insert slot before removal) — against
/// the panel [rows], topmost first. Returns null for a no-op drop.
///
/// An insertion slot belongs to a group when the row directly above it is
/// that group's expanded header or one of its children — so a drop right
/// under the header, between children, or after the last child all enter
/// the group, and a collapsed group opens no slots. A Group row itself
/// never nests: dropped inside a run it lands at the top level right below
/// the holder instead (one-level nesting stays the canvas's rule).
LayersDropPlan? layersDropPlan(List<LayerRowEntry> rows, int from, int to) {
  if (from < 0 || from >= rows.length) return null;
  final dragged = rows[from];
  final removed = [...rows]..removeAt(from);
  final slot = (to > from ? to - 1 : to).clamp(0, removed.length);
  final before = slot == 0 ? null : removed[slot - 1];
  String? holder;
  if (before != null && before.parent != null) {
    holder = before.parent;
  } else if (before != null && before.expanded) {
    holder = before.id;
  }
  if (holder == dragged.id) return null;
  if (dragged.isGroup) holder = null;
  int within(String? parent, Iterable<LayerRowEntry> entries) =>
      entries.where((entry) => entry.parent == parent).length;
  if (holder == dragged.parent) {
    final position = within(holder, removed.take(slot));
    if (position == within(holder, rows.take(from))) return null;
    return LayersReorder(dragged.id, within(holder, rows) - 1 - position);
  }
  final position = within(holder, removed.take(slot));
  if (holder == null) {
    return LayersMoveOut(dragged.id, dragged.parent!, within(null, rows) - position);
  }
  return LayersMoveIn(dragged.id, holder, within(holder, rows) - position);
}
