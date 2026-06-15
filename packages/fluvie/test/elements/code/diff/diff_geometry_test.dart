// WI-10 (D-Diff): the pure per-op diff geometry. Given the op list and a 0..1
// progress, layoutDiff returns one DiffLine per op carrying (opacity, y, height
// factor, gutter color). No canvas — the geometry is a pure function of the ops
// and the progress, so the motion is unit-testable directly.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/code/diff/diff_geometry.dart';
import 'package:fluvie/src/elements/code/diff/diff_op.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';

const _theme = CodeTheme.dark();
const _lineHeight = 20.0;

void main() {
  group('diffLineGeometry at progress 0 (the before document)', () {
    test('a Remove line is fully visible and at full height', () {
      final line = diffLineGeometry(const Remove('x'), 0, _theme);
      expect(line.opacity, 1.0);
      expect(line.heightFactor, 1.0);
      expect(line.gutter, _theme.removedGutter);
    });

    test('an Insert line is invisible and collapsed', () {
      final line = diffLineGeometry(const Insert('y'), 0, _theme);
      expect(line.opacity, 0.0);
      expect(line.heightFactor, 0.0);
      expect(line.gutter, _theme.addedGutter);
    });

    test('a Keep line is fully visible at full height with no gutter', () {
      final line = diffLineGeometry(const Keep('a'), 0, _theme);
      expect(line.opacity, 1.0);
      expect(line.heightFactor, 1.0);
      expect(line.gutter, isNull);
    });
  });

  group('diffLineGeometry at progress 1 (the after document)', () {
    test('a Remove line is invisible and collapsed', () {
      final line = diffLineGeometry(const Remove('x'), 1, _theme);
      expect(line.opacity, 0.0);
      expect(line.heightFactor, 0.0);
      expect(line.gutter, _theme.removedGutter);
    });

    test('an Insert line is fully visible at full height', () {
      final line = diffLineGeometry(const Insert('y'), 1, _theme);
      expect(line.opacity, 1.0);
      expect(line.heightFactor, 1.0);
      expect(line.gutter, _theme.addedGutter);
    });

    test('a Keep line stays fully visible', () {
      final line = diffLineGeometry(const Keep('a'), 1, _theme);
      expect(line.opacity, 1.0);
      expect(line.heightFactor, 1.0);
      expect(line.gutter, isNull);
    });
  });

  group('diffLineGeometry mid-progress', () {
    test('a Remove line is fading out and collapsing', () {
      final line = diffLineGeometry(const Remove('x'), 0.5, _theme);
      expect(line.opacity, greaterThan(0.0));
      expect(line.opacity, lessThan(1.0));
      expect(line.heightFactor, greaterThan(0.0));
      expect(line.heightFactor, lessThan(1.0));
      expect(line.gutter, _theme.removedGutter);
    });

    test('an Insert line is fading in and expanding', () {
      final line = diffLineGeometry(const Insert('y'), 0.5, _theme);
      expect(line.opacity, greaterThan(0.0));
      expect(line.opacity, lessThan(1.0));
      expect(line.heightFactor, greaterThan(0.0));
      expect(line.heightFactor, lessThan(1.0));
      expect(line.gutter, _theme.addedGutter);
    });

    test('progress is clamped outside 0..1', () {
      expect(diffLineGeometry(const Insert('y'), -1, _theme).opacity, 0.0);
      expect(diffLineGeometry(const Insert('y'), 2, _theme).opacity, 1.0);
    });
  });

  group('layoutDiff vertical positions', () {
    test('each line sits below the swept height of the lines before it', () {
      // before: [a, x], after: [a, y] -> Keep a, Remove x, Insert y.
      final ops = [const Keep('a'), const Remove('x'), const Insert('y')];

      final atZero = layoutDiff(ops: ops, progress: 0, theme: _theme, lineHeight: _lineHeight);
      // At progress 0 the Insert is collapsed, so the kept line a is at y 0 and
      // the removed line x sits one full line below it.
      expect(atZero[0].y, 0.0);
      expect(atZero[1].y, _lineHeight);
      // The insert is collapsed (height 0), so it shares x's bottom edge.
      expect(atZero[2].y, _lineHeight * 2);

      final atOne = layoutDiff(ops: ops, progress: 1, theme: _theme, lineHeight: _lineHeight);
      // At progress 1 the Remove collapsed; the insert took its slot.
      expect(atOne[0].y, 0.0);
      expect(atOne[1].y, _lineHeight); // remove collapsed at the same baseline
      expect(atOne[2].y, _lineHeight); // insert now occupies the slot
    });

    test('returns one DiffLine per op carrying the op text', () {
      final lines = layoutDiff(
        ops: [const Keep('a'), const Insert('b')],
        progress: 0.4,
        theme: _theme,
        lineHeight: _lineHeight,
      );
      expect(lines.map((l) => l.text), const ['a', 'b']);
    });

    test('the total swept height grows from before-height to after-height', () {
      final ops = [const Remove('x'), const Insert('y')];
      final h0 = totalDiffHeight(ops: ops, progress: 0, lineHeight: _lineHeight);
      final h1 = totalDiffHeight(ops: ops, progress: 1, lineHeight: _lineHeight);
      // before has one visible line (x), after has one (y): equal totals here,
      // but mid-progress both contribute partial height (the cross-fade slot).
      expect(h0, _lineHeight);
      expect(h1, _lineHeight);
      final hMid = totalDiffHeight(ops: ops, progress: 0.5, lineHeight: _lineHeight);
      expect(hMid, _lineHeight); // 0.5 + 0.5
    });

    test('is deterministic', () {
      final ops = [const Keep('a'), const Remove('b'), const Insert('c')];
      expect(
        layoutDiff(ops: ops, progress: 0.3, theme: _theme, lineHeight: _lineHeight),
        layoutDiff(ops: ops, progress: 0.3, theme: _theme, lineHeight: _lineHeight),
      );
    });
  });

  group('DiffLine value semantics', () {
    test('is value-equal by field with a matching hashCode', () {
      final a = diffLineGeometry(const Keep('a'), 0, _theme);
      final b = diffLineGeometry(const Keep('a'), 0, _theme);
      final c = diffLineGeometry(const Keep('b'), 0, _theme);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('has a readable toString', () {
      expect(diffLineGeometry(const Keep('a'), 0, _theme).toString(), contains('DiffLine'));
    });
  });
}
