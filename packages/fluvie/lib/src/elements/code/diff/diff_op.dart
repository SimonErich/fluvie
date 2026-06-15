/// @docImport 'package:fluvie/src/core/stagger.dart';
/// @docImport 'package:fluvie/src/elements/code/code_reveal.dart';
/// @docImport 'package:fluvie/src/elements/code/diff/line_diff.dart';
library;

import 'package:meta/meta.dart' show immutable;

/// One step in a line-level diff between a `before` and an `after` document: a
/// line that is kept, inserted, or removed.
///
/// A sealed value type, mirroring `CodeReveal` and `Stagger`: [lineDiff] returns
/// an ordered `List<DiffOp>` and the diff painter switches over the three
/// variants to drive the add / remove / change motion. Every op carries the
/// literal [line] text (no trailing newline) and is value-equal by it, so two
/// diffs of the same documents produce identical op lists and the highlight /
/// repaint caches stay frame-stable.
@immutable
sealed class DiffOp {
  const DiffOp(this.line);

  /// The literal line text this op describes (no trailing newline).
  final String line;
}

/// A line present in both documents, unchanged: it slides to its new vertical
/// position over the diff window.
@immutable
final class Keep extends DiffOp {
  /// Creates a kept-line op over [line].
  const Keep(super.line);

  @override
  bool operator ==(Object other) => other is Keep && other.line == line;

  @override
  int get hashCode => Object.hash(Keep, line);

  @override
  String toString() => 'Keep($line)';
}

/// A line present only in the `after` document: it fades in and expands over the
/// diff window, with a green gutter.
@immutable
final class Insert extends DiffOp {
  /// Creates an inserted-line op over [line].
  const Insert(super.line);

  @override
  bool operator ==(Object other) => other is Insert && other.line == line;

  @override
  int get hashCode => Object.hash(Insert, line);

  @override
  String toString() => 'Insert($line)';
}

/// A line present only in the `before` document: it fades out and collapses over
/// the diff window, with a red gutter.
@immutable
final class Remove extends DiffOp {
  /// Creates a removed-line op over [line].
  const Remove(super.line);

  @override
  bool operator ==(Object other) => other is Remove && other.line == line;

  @override
  int get hashCode => Object.hash(Remove, line);

  @override
  String toString() => 'Remove($line)';
}
