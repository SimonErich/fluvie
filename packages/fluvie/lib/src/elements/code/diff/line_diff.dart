import 'package:fluvie/src/elements/code/diff/diff_op.dart';

/// The line-level diff between [before] and [after] as an ordered op list — a
/// pure LCS edit script.
///
/// Computes the longest common subsequence of the two line lists, then walks
/// both in order: lines in the LCS become [Keep], lines only in [before] become
/// [Remove], and lines only in [after] become [Insert]. A changed line is a
/// [Remove] of the old text followed by an [Insert] of the new. LCS is adequate
/// at line granularity (Myers is unnecessary here) and is a pure function of the
/// inputs — no clock, no randomness — so the same documents always diff to the
/// identical op list, which keeps the diff motion byte-stable.
///
/// The op order reconstructs [after] when [Keep] + [Insert] lines are emitted
/// and [Remove] lines are skipped.
List<DiffOp> lineDiff(List<String> before, List<String> after) {
  final table = _lcsTable(before, after);
  final ops = <DiffOp>[];
  var i = 0;
  var j = 0;
  while (i < before.length && j < after.length) {
    if (before[i] == after[j]) {
      ops.add(Keep(before[i]));
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      ops.add(Remove(before[i]));
      i++;
    } else {
      ops.add(Insert(after[j]));
      j++;
    }
  }
  while (i < before.length) {
    ops.add(Remove(before[i]));
    i++;
  }
  while (j < after.length) {
    ops.add(Insert(after[j]));
    j++;
  }
  return List<DiffOp>.unmodifiable(ops);
}

/// The LCS-length dynamic-programming table: `table[i][j]` is the length of the
/// longest common subsequence of `before[i:]` and `after[j:]`.
List<List<int>> _lcsTable(List<String> before, List<String> after) {
  final table = [
    for (var i = 0; i <= before.length; i++) List<int>.filled(after.length + 1, 0),
  ];
  for (var i = before.length - 1; i >= 0; i--) {
    for (var j = after.length - 1; j >= 0; j--) {
      table[i][j] = before[i] == after[j]
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] > table[i][j + 1] ? table[i + 1][j] : table[i][j + 1]);
    }
  }
  return table;
}
