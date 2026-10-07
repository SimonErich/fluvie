import 'package:meta/meta.dart';

/// The smart-block layouts the editor can arrange a `Group` into.
///
/// A block is editor metadata over a plain spec `Group`: the kind and its
/// parameters live under `editor.elements.<groupId>.block`, while the
/// arranged transforms are real spec transforms on the children — so a deck
/// with blocks renders everywhere, block-aware or not.
enum BlockKind {
  /// Children side by side along the horizontal axis.
  row,

  /// Children stacked along the vertical axis.
  column,

  /// Children filling a fixed-column grid, left to right, top to bottom.
  grid,

  /// Full-width rows of a fixed item height, stacked from the top.
  list,

  /// Two columns at a ratio; extra children flow into the second column.
  split,

  /// A header band over a body column.
  titleBody;

  /// The short chip text the layers panel and menus show.
  String get label => this == BlockKind.titleBody ? 'title' : name;
}

/// How a row or column packs its children along the main axis.
enum BlockMainAlign {
  /// Packed from the leading edge.
  start,

  /// Centered as one run.
  center,

  /// Packed against the trailing edge.
  end,

  /// The leftover axis spreads into equal gaps between the children.
  spaceBetween,
}

/// How a row or column places its children across the other axis.
enum BlockCrossAlign {
  /// Against the leading cross edge, keeping each child's own extent.
  start,

  /// Centered, keeping each child's own extent.
  center,

  /// Against the trailing cross edge, keeping each child's own extent.
  end,

  /// Every child fills the whole cross axis.
  stretch,
}

/// One block's kind and parameters, as stored in the editor block.
///
/// All lengths are fractions of the block group's own box, so a resized
/// group scales its arrangement with it. [fromJson] clamps every parameter
/// into a sane range and reads anything unrecognized as "not a block".
@immutable
final class BlockSpec {
  const BlockSpec._({
    required this.kind,
    this.spacing = 0.04,
    this.mainAlign = BlockMainAlign.start,
    this.crossAlign = BlockCrossAlign.stretch,
    this.equalSize = true,
    this.columns = 2,
    this.itemHeight = 0.18,
    this.ratio = 0.5,
    this.gutter = 0.04,
    this.heightFraction = 0.25,
  });

  /// The default parameters for [kind] — what "Make block" starts from.
  factory BlockSpec.defaults(BlockKind kind) => BlockSpec._(kind: kind);

  /// Reads a block from the editor-block metadata value, or null when the
  /// value is not a block (absent, malformed, or an unknown kind).
  static BlockSpec? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final kind = _kinds[json['kind']];
    if (kind == null) return null;
    return BlockSpec._(
      kind: kind,
      spacing: _clamped(json['spacing'], 0.04, 0, 0.5),
      mainAlign: _mainAligns[json['mainAlign']] ?? BlockMainAlign.start,
      crossAlign: _crossAligns[json['crossAlign']] ?? BlockCrossAlign.stretch,
      equalSize: json['equalSize'] != false,
      columns: json['columns'] is num ? (json['columns']! as num).round().clamp(1, 12) : 2,
      itemHeight: _clamped(json['itemHeight'], 0.18, 0.01, 1),
      ratio: _clamped(json['ratio'], 0.5, 0.05, 0.95),
      gutter: _clamped(json['gutter'], 0.04, 0, 0.5),
      heightFraction: _clamped(json['heightFraction'], 0.25, 0.05, 0.95),
    );
  }

  /// Which layout this block arranges.
  final BlockKind kind;

  /// The gap between children, as a fraction of the main axis (rows,
  /// columns, lists) or of both axes (grids).
  final double spacing;

  /// Main-axis packing for rows and columns (matters when [equalSize] is
  /// off; equal-size children always fill the axis).
  final BlockMainAlign mainAlign;

  /// Cross-axis placement for rows and columns.
  final BlockCrossAlign crossAlign;

  /// Whether a row or column assigns every child the same main-axis share.
  /// Off, children keep their own stored extents and only get repacked.
  final bool equalSize;

  /// How many columns a grid lays out.
  final int columns;

  /// A list row's height, as a fraction of the group's height.
  final double itemHeight;

  /// The first column's share of a split, 0.05 to 0.95.
  final double ratio;

  /// The gap between a split's columns (and between its flowed rows).
  final double gutter;

  /// The title band's share of a title-body block's height.
  final double heightFraction;

  /// The stored form: the kind plus only the parameters that kind reads.
  Map<String, Object?> toJson() => switch (kind) {
    BlockKind.row || BlockKind.column => {
      'kind': kind.name,
      'spacing': spacing,
      'mainAlign': mainAlign.name,
      'crossAlign': crossAlign.name,
      'equalSize': equalSize,
    },
    BlockKind.grid => {'kind': 'grid', 'columns': columns, 'spacing': spacing},
    BlockKind.list => {'kind': 'list', 'itemHeight': itemHeight, 'spacing': spacing},
    BlockKind.split => {'kind': 'split', 'ratio': ratio, 'gutter': gutter},
    BlockKind.titleBody => {
      'kind': 'titleBody',
      'heightFraction': heightFraction,
      'spacing': spacing,
    },
  };

  static final Map<Object?, BlockKind> _kinds = {
    for (final kind in BlockKind.values) kind.name: kind,
  };
  static final Map<Object?, BlockMainAlign> _mainAligns = {
    for (final align in BlockMainAlign.values) align.name: align,
  };
  static final Map<Object?, BlockCrossAlign> _crossAligns = {
    for (final align in BlockCrossAlign.values) align.name: align,
  };

  static double _clamped(Object? value, double fallback, double min, double max) =>
      value is num ? value.toDouble().clamp(min, max) : fallback;
}
