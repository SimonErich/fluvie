import 'dart:ui' show Color;

import 'package:fluvie/src/elements/code/diff/diff_op.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:meta/meta.dart' show immutable;

/// One laid-out diff line at a given progress: its [text], its
/// painted [opacity], its vertical [y] offset, its [heightFactor] (`0..1` of a
/// full line, so a collapsing / expanding line takes less vertical room), and
/// its [gutter] color (red for a removal, green for an insertion, `null` for a
/// kept line).
///
/// Value-equal by field so two builds of the same diff frame produce identical
/// geometry and the painter's `shouldRepaint` stays frame-stable.
@immutable
final class DiffLine {
  /// Creates a laid-out diff line.
  const DiffLine({
    required this.text,
    required this.opacity,
    required this.y,
    required this.heightFactor,
    required this.gutter,
  });

  /// The literal line text (no trailing newline).
  final String text;

  /// The painted opacity (`0..1`): full for a settled line, partial mid-fade.
  final double opacity;

  /// The top of this line in pixels, after the swept heights of the lines above.
  final double y;

  /// The fraction (`0..1`) of a full line height this line currently occupies.
  final double heightFactor;

  /// The gutter color, or `null` for a kept line (no add / remove stripe).
  final Color? gutter;

  @override
  bool operator ==(Object other) =>
      other is DiffLine &&
      other.text == text &&
      other.opacity == opacity &&
      other.y == y &&
      other.heightFactor == heightFactor &&
      other.gutter == gutter;

  @override
  int get hashCode => Object.hash(DiffLine, text, opacity, y, heightFactor, gutter);

  @override
  String toString() => 'DiffLine($text, opacity: $opacity, y: $y, h: $heightFactor)';
}

/// The visual state of one [op] at [progress], independent of its vertical
/// position.
///
/// A [Keep] is fully visible at full height with no gutter throughout. A
/// [Remove] starts full and fades / collapses to nothing as [progress] goes
/// `0 -> 1`, carrying the [CodeTheme.removedGutter]. An [Insert] starts at
/// nothing and fades / expands to full, carrying the [CodeTheme.addedGutter].
/// [progress] is clamped to `[0, 1]`, so the geometry is a pure function of the
/// op and the frame's progress.
DiffLine diffLineGeometry(DiffOp op, double progress, CodeTheme theme) {
  final p = progress.clamp(0.0, 1.0);
  return switch (op) {
    Keep(:final line) => DiffLine(
      text: line,
      opacity: 1,
      y: 0,
      heightFactor: 1,
      gutter: null,
    ),
    Remove(:final line) => DiffLine(
      text: line,
      opacity: 1 - p,
      y: 0,
      heightFactor: 1 - p,
      gutter: theme.removedGutter,
    ),
    Insert(:final line) => DiffLine(
      text: line,
      opacity: p,
      y: 0,
      heightFactor: p,
      gutter: theme.addedGutter,
    ),
  };
}

/// The full per-op diff layout at [progress]: one [DiffLine]
/// per op, stacked top to bottom by each line's swept height so removed lines
/// collapse and inserted lines expand into their slot.
///
/// Each line's vertical [DiffLine.y] is the running sum of the swept heights
/// (`heightFactor * lineHeight`) of the lines above it, so the document grows
/// and shrinks smoothly with no overlap or gap. Pure: identical inputs always
/// return identical geometry.
List<DiffLine> layoutDiff({
  required List<DiffOp> ops,
  required double progress,
  required CodeTheme theme,
  required double lineHeight,
}) {
  final lines = <DiffLine>[];
  var y = 0.0;
  for (final op in ops) {
    final base = diffLineGeometry(op, progress, theme);
    lines.add(
      DiffLine(
        text: base.text,
        opacity: base.opacity,
        y: y,
        heightFactor: base.heightFactor,
        gutter: base.gutter,
      ),
    );
    y += base.heightFactor * lineHeight;
  }
  return List<DiffLine>.unmodifiable(lines);
}

/// The total swept height of the diff at [progress]: the sum of every op's
/// height factor times [lineHeight].
double totalDiffHeight({
  required List<DiffOp> ops,
  required double progress,
  required double lineHeight,
}) {
  final p = progress.clamp(0.0, 1.0);
  var total = 0.0;
  for (final op in ops) {
    total += switch (op) {
      Keep() => lineHeight,
      Remove() => (1 - p) * lineHeight,
      Insert() => p * lineHeight,
    };
  }
  return total;
}
