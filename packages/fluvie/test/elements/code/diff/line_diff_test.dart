// WI-9 (D-Diff): the pure LCS line-diff and its sealed DiffOp value type. No
// goldens, no canvas — lineDiff is a pure function of (before, after) and every
// op is value-equal, so these unit tests pin the algorithm directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/code/diff/diff_op.dart';
import 'package:fluvie/src/elements/code/diff/line_diff.dart';

/// Applies [ops] (keeping Keep + Insert lines, skipping Remove) to reconstruct
/// the `after` document the diff produced.
List<String> _reconstruct(List<DiffOp> ops) => [
  for (final op in ops)
    if (op is Keep) op.line else if (op is Insert) op.line,
];

void main() {
  group('DiffOp value equality', () {
    test('Keep is value-equal by line', () {
      expect(const Keep('a'), const Keep('a'));
      expect(const Keep('a'), isNot(const Keep('b')));
      expect(const Keep('a').hashCode, const Keep('a').hashCode);
      expect(const Keep('a').line, 'a');
    });

    test('Insert is value-equal by line', () {
      expect(const Insert('a'), const Insert('a'));
      expect(const Insert('a'), isNot(const Insert('b')));
      expect(const Insert('a').hashCode, const Insert('a').hashCode);
      expect(const Insert('a').line, 'a');
    });

    test('Remove is value-equal by line', () {
      expect(const Remove('a'), const Remove('a'));
      expect(const Remove('a'), isNot(const Remove('b')));
      expect(const Remove('a').hashCode, const Remove('a').hashCode);
      expect(const Remove('a').line, 'a');
    });

    test('the three op kinds with the same line are not equal', () {
      expect(const Keep('a'), isNot(const Insert('a')));
      expect(const Keep('a'), isNot(const Remove('a')));
      expect(const Insert('a'), isNot(const Remove('a')));
    });

    test('each op stringifies to its kind and line', () {
      expect(const Keep('a').toString(), 'Keep(a)');
      expect(const Insert('a').toString(), 'Insert(a)');
      expect(const Remove('a').toString(), 'Remove(a)');
    });
  });

  group('lineDiff', () {
    test('empty before and after yields no ops', () {
      expect(lineDiff(const [], const []), isEmpty);
    });

    test('identical inputs are all Keep', () {
      final ops = lineDiff(const ['a', 'b', 'c'], const ['a', 'b', 'c']);
      expect(ops, const [Keep('a'), Keep('b'), Keep('c')]);
    });

    test('an inserted line yields one Insert with surrounding Keeps', () {
      final ops = lineDiff(const ['a', 'c'], const ['a', 'b', 'c']);
      expect(ops, const [Keep('a'), Insert('b'), Keep('c')]);
    });

    test('a removed line yields one Remove with surrounding Keeps', () {
      final ops = lineDiff(const ['a', 'b', 'c'], const ['a', 'c']);
      expect(ops, const [Keep('a'), Remove('b'), Keep('c')]);
    });

    test('a changed line yields a Remove + Insert pair', () {
      final ops = lineDiff(const ['a', 'b', 'c'], const ['a', 'x', 'c']);
      expect(ops, const [Keep('a'), Remove('b'), Insert('x'), Keep('c')]);
    });

    test('all-removed yields only Removes', () {
      expect(lineDiff(const ['a', 'b'], const []), const [Remove('a'), Remove('b')]);
    });

    test('all-inserted yields only Inserts', () {
      expect(lineDiff(const [], const ['a', 'b']), const [Insert('a'), Insert('b')]);
    });

    test('a reorder resolves via LCS to the minimal op set', () {
      // LCS of [a,b] and [b,a] is one line; the minimal edit removes one and
      // inserts one rather than touching both.
      final ops = lineDiff(const ['a', 'b'], const ['b', 'a']);
      final removes = ops.whereType<Remove>().length;
      final inserts = ops.whereType<Insert>().length;
      final keeps = ops.whereType<Keep>().length;
      expect(keeps, 1);
      expect(removes, 1);
      expect(inserts, 1);
    });

    test('duplicate lines diff against the longest common subsequence', () {
      // before "a a b", after "a b": one of the two leading "a"s is removed.
      final ops = lineDiff(const ['a', 'a', 'b'], const ['a', 'b']);
      expect(ops.whereType<Remove>().map((o) => o.line), const ['a']);
      expect(ops.whereType<Keep>().map((o) => o.line), const ['a', 'b']);
      expect(ops.whereType<Insert>(), isEmpty);
    });

    test('the op sequence reconstructs after', () {
      const before = ['import a', 'class A {', '  int x;', '}'];
      const after = ['import a', 'import b', 'class A {', '  int y;', '}'];
      expect(_reconstruct(lineDiff(before, after)), after);
    });

    test('is deterministic across calls', () {
      const before = ['a', 'b', 'c', 'd'];
      const after = ['a', 'x', 'c', 'd', 'e'];
      expect(lineDiff(before, after), lineDiff(before, after));
    });
  });
}
