/// The four z-order moves of the arrange menu.
enum ArrangeOrder {
  /// Swap each moved element with its unselected neighbor above.
  forward,

  /// Swap each moved element with its unselected neighbor below.
  backward,

  /// Lift the moved set to the top of its list.
  front,

  /// Drop the moved set to the bottom of its list.
  back,
}

/// The new z-order after applying [order] to the [moving] ids within
/// [current] (bottom-most first, the children-list order).
///
/// Multi-selections keep their relative order (the Figma semantics): a
/// forward or backward step swaps each moved id with its nearest unselected
/// neighbor and blocks at the list edge, so a run of moved ids travels as a
/// unit. Ids absent from [current] are ignored.
List<String> arrangedIds(List<String> current, Set<String> moving, ArrangeOrder order) {
  final moved = moving.where(current.contains).toSet();
  if (moved.isEmpty) return [...current];
  switch (order) {
    case ArrangeOrder.forward:
      final result = [...current];
      for (var i = result.length - 2; i >= 0; i--) {
        if (moved.contains(result[i]) && !moved.contains(result[i + 1])) {
          final lifted = result.removeAt(i);
          result.insert(i + 1, lifted);
        }
      }
      return result;
    case ArrangeOrder.backward:
      final result = [...current];
      for (var i = 1; i < result.length; i++) {
        if (moved.contains(result[i]) && !moved.contains(result[i - 1])) {
          final dropped = result.removeAt(i);
          result.insert(i - 1, dropped);
        }
      }
      return result;
    case ArrangeOrder.front:
      return [
        ...current.where((id) => !moved.contains(id)),
        ...current.where(moved.contains),
      ];
    case ArrangeOrder.back:
      return [
        ...current.where(moved.contains),
        ...current.where((id) => !moved.contains(id)),
      ];
  }
}
