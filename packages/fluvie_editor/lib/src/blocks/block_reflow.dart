import 'package:fluvie_editor/src/blocks/block_spec.dart';

/// The pure reflow engine behind smart blocks: given a block's parameters
/// and its group's children (in z-order), it returns the new group-relative
/// transform for every child.
///
/// All values are fractions of the group's box. Every output is an explicit
/// centered box (`x`/`y`/`w`/`h`); a child's authored `rotation` and
/// `opacity` ride along untouched. A nested block group is one box here —
/// its own children keep their fractions and scale with it.
Map<String, Map<String, Object?>> reflowedBlockTransforms(
  BlockSpec block,
  List<Map<String, Object?>> children,
) {
  if (children.isEmpty) return const {};
  final boxes = switch (block.kind) {
    BlockKind.row => _line(block, children, horizontal: true),
    BlockKind.column => _line(block, children, horizontal: false),
    BlockKind.grid => _grid(block, children.length),
    BlockKind.list => _list(block, children.length),
    BlockKind.split => _split(block, children.length),
    BlockKind.titleBody => _titleBody(block, children.length),
  };
  final out = <String, Map<String, Object?>>{};
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    final id = child['id'];
    if (id is! String) continue;
    out[id] = _transformJson(boxes[i], child['transform']);
  }
  return out;
}

/// A computed slot: center position and extent per axis, group fractions.
typedef _Box = ({double x, double y, double w, double h});

/// Extents never collapse: pathological parameters clamp at 1% of the box.
double _positive(double extent) => extent < 0.01 ? 0.01 : extent;

Map<String, Object?> _transformJson(_Box box, Object? previous) {
  final carried = previous is Map<String, Object?> ? previous : const <String, Object?>{};
  return {
    'x': box.x,
    'y': box.y,
    'w': box.w,
    'h': box.h,
    if (carried['rotation'] case final num rotation) 'rotation': rotation,
    if (carried['opacity'] case final num opacity) 'opacity': opacity,
  };
}

/// The stored extent of one child along an axis, or null for intrinsic.
double? _storedExtent(Map<String, Object?> child, String key) {
  final transform = child['transform'];
  if (transform is! Map<String, Object?>) return null;
  final value = transform[key];
  return value is num ? value.toDouble() : null;
}

/// Rows and columns: one packed line along the main axis.
List<_Box> _line(
  BlockSpec block,
  List<Map<String, Object?>> children, {
  required bool horizontal,
}) {
  final n = children.length;
  final gapTotal = block.spacing * (n - 1);
  final share = _positive((1 - gapTotal) / n);
  final mainKey = horizontal ? 'w' : 'h';
  final crossKey = horizontal ? 'h' : 'w';
  final extents = [
    for (final child in children)
      if (block.equalSize) share else (_storedExtent(child, mainKey) ?? share),
  ];
  final sum = extents.fold<double>(0, (total, extent) => total + extent);
  final spaceBetween = block.mainAlign == BlockMainAlign.spaceBetween && n > 1;
  final gap = spaceBetween ? (1 - sum) / (n - 1) : block.spacing;
  var cursor = switch (block.mainAlign) {
    BlockMainAlign.center => (1 - sum - gapTotal) / 2,
    BlockMainAlign.end => 1 - sum - gapTotal,
    BlockMainAlign.start || BlockMainAlign.spaceBetween => 0.0,
  };
  final boxes = <_Box>[];
  for (var i = 0; i < n; i++) {
    final main = extents[i];
    final cross = block.crossAlign == BlockCrossAlign.stretch
        ? 1.0
        : (_storedExtent(children[i], crossKey) ?? 1.0);
    final crossCenter = switch (block.crossAlign) {
      BlockCrossAlign.start => cross / 2,
      BlockCrossAlign.end => 1 - cross / 2,
      BlockCrossAlign.center || BlockCrossAlign.stretch => 0.5,
    };
    final mainCenter = cursor + main / 2;
    boxes.add(
      horizontal
          ? (x: mainCenter, y: crossCenter, w: main, h: cross)
          : (x: crossCenter, y: mainCenter, w: cross, h: main),
    );
    cursor += main + gap;
  }
  return boxes;
}

/// A fixed-column grid of equal cells, filled left to right, top to bottom.
List<_Box> _grid(BlockSpec block, int count) {
  final columns = block.columns;
  final rows = (count + columns - 1) ~/ columns;
  final cellW = _positive((1 - block.spacing * (columns - 1)) / columns);
  final cellH = _positive((1 - block.spacing * (rows - 1)) / rows);
  return [
    for (var i = 0; i < count; i++)
      (
        x: (i % columns) * (cellW + block.spacing) + cellW / 2,
        y: (i ~/ columns) * (cellH + block.spacing) + cellH / 2,
        w: cellW,
        h: cellH,
      ),
  ];
}

/// Full-width rows of the item height, stacked from the top.
List<_Box> _list(BlockSpec block, int count) => [
  for (var i = 0; i < count; i++)
    (
      x: 0.5,
      y: i * (block.itemHeight + block.spacing) + block.itemHeight / 2,
      w: 1.0,
      h: _positive(block.itemHeight),
    ),
];

/// Two columns at the ratio; children past the first flow into the second
/// column as a stacked run.
List<_Box> _split(BlockSpec block, int count) {
  final leftW = _positive(block.ratio - block.gutter / 2);
  final rightW = _positive(1 - block.ratio - block.gutter / 2);
  final rightX = block.ratio + block.gutter / 2 + rightW / 2;
  final flowed = count - 1;
  final rowH = flowed == 0 ? 1.0 : _positive((1 - block.gutter * (flowed - 1)) / flowed);
  return [
    (x: leftW / 2, y: 0.5, w: leftW, h: 1.0),
    for (var i = 0; i < flowed; i++)
      (x: rightX, y: i * (rowH + block.gutter) + rowH / 2, w: rightW, h: rowH),
  ];
}

/// A header band over a stacked body column.
List<_Box> _titleBody(BlockSpec block, int count) {
  final band = _positive(block.heightFraction);
  final body = count - 1;
  final top = band + block.spacing;
  final rowH = body == 0 ? 1.0 : _positive((1 - top - block.spacing * (body - 1)) / body);
  return [
    (x: 0.5, y: band / 2, w: 1.0, h: band),
    for (var i = 0; i < body; i++)
      (x: 0.5, y: top + i * (rowH + block.spacing) + rowH / 2, w: 1.0, h: rowH),
  ];
}
