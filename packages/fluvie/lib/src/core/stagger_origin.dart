/// Where a stagger wave starts among a target's children.
///
/// Used by `Stagger.from` to order multi-child animation offsets; the
/// distribution math runs in the resolver, this enum only names the origin.
enum StaggerOrigin {
  /// Natural order: the first child leads, the last trails.
  start,

  /// Center-out: the middle child leads, the wave spreads to both ends.
  center,

  /// Reverse order: the last child leads, the first trails.
  end,

  /// Edges-in: the outermost children lead, the wave meets in the middle.
  edges,
}
