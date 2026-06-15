/// One named filter in an FFmpeg filter graph, e.g. `format=pix_fmts=yuv420p`.
///
/// A node is typed data, never a hand-built string: argument values are
/// escaped on serialization and node names must come from the known-safe set
/// this library actually emits (`format`, `scale`, `fps`). New filters join
/// the set when a phase needs them — the allowlist is the security boundary
/// that keeps arbitrary strings out of the encoder command line.
final class FilterNode {
  /// Creates a node for the filter [name] with named [args].
  ///
  /// Argument order is preserved into [serialize], so callers control the
  /// exact emitted form deterministically.
  FilterNode(this.name, {Map<String, String> args = const {}})
    : assert(
        _safeNames.contains(name),
        'Unknown filter "$name": FilterNode only emits the known-safe set $_safeNames.',
      ),
      args = Map.unmodifiable(Map.of(args));

  /// The filter names this library is allowed to emit.
  static const Set<String> _safeNames = {'format', 'scale', 'fps'};

  /// The FFmpeg filter name, from the known-safe set.
  final String name;

  /// The filter's named arguments in serialization order (unmodifiable).
  final Map<String, String> args;

  /// The `name=key=value:key=value` form with all values escaped.
  String serialize() {
    if (args.isEmpty) return name;
    final body = args.entries.map((e) => '${e.key}=${_escape(e.value)}').join(':');
    return '$name=$body';
  }

  /// Escapes the filter-graph specials `\`, `:`, `,` and `'` in [value]
  /// (backslash first, so escapes are never themselves re-escaped).
  static String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(':', r'\:')
      .replaceAll(',', r'\,')
      .replaceAll("'", r"\'");
}

/// An ordered chain of [FilterNode]s, serialized as one `-vf` value.
///
/// Nodes serialize in insertion order joined by `,` — the plan is fully
/// deterministic, which the encode-twice byte-equality tests rely on.
final class FfmpegFilterGraph {
  final List<FilterNode> _nodes = [];

  /// Whether no node has been added yet (an empty graph emits no `-vf`).
  bool get isEmpty => _nodes.isEmpty;

  /// Appends [node] to the chain.
  void add(FilterNode node) => _nodes.add(node);

  /// The comma-joined chain, e.g. `format=pix_fmts=yuv420p,scale=w=320:h=240`.
  String serialize() => _nodes.map((node) => node.serialize()).join(',');
}
