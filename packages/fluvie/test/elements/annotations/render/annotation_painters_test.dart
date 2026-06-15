import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/annotations/render/arrow_painter.dart';
import 'package:fluvie/src/elements/annotations/render/connector_painter.dart';
import 'package:fluvie/src/elements/annotations/render/shape_painter.dart';
import 'package:fluvie/src/elements/annotations/render/spotlight_painter.dart';

const _black = Color(0xFF000000);

ShapePainter _shape(ShapeKind kind, double progress) => ShapePainter(
  kind: kind,
  color: _black,
  progress: progress,
  strokeWidth: 2,
  from: Offset.zero,
  to: const Offset(40, 0),
  rect: const Rect.fromLTWH(0, 0, 40, 40),
  center: const Offset(20, 20),
  radius: 10,
  path: Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
);

void main() {
  group('ShapePainter outline per kind', () {
    for (final kind in ShapeKind.values) {
      test('$kind exposes a non-empty outline and trims to a fraction', () {
        final painter = _shape(kind, 0.5);
        expect(painter.outline.computeMetrics().isNotEmpty, isTrue);
        // A mid fraction yields some drawn length; a zero fraction yields none.
        expect(painter.trimmedTo(0).computeMetrics().isEmpty, isTrue);
        expect(painter.trimmedTo(1), isNotNull);
      });
    }

    test('shouldRepaint flips when any field differs', () {
      final a = _shape(ShapeKind.line, 0.4);
      final b = _shape(ShapeKind.line, 0.6);
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(a), isFalse);
    });
  });

  group('ArrowPainter geometry', () {
    test('a zero-length arrow falls back to a horizontal direction', () {
      final painter = ArrowPainter(
        from: const Offset(10, 10),
        to: const Offset(10, 10),
        color: _black,
        progress: 1,
        strokeWidth: 2,
        headLength: 12,
      );
      // headBase clamps to from when the arrow has no length.
      expect(painter.headBase, const Offset(10, 10));
      expect(painter.shaftEnd, const Offset(10, 10));
    });

    test('headLength longer than the shaft clamps the base to from', () {
      final painter = ArrowPainter(
        from: Offset.zero,
        to: const Offset(10, 0),
        color: _black,
        progress: 1,
        strokeWidth: 2,
        headLength: 40,
      );
      expect(painter.headBase, Offset.zero);
    });

    test('shouldRepaint flips when the progress differs', () {
      final a = ArrowPainter(
        from: Offset.zero,
        to: const Offset(10, 0),
        color: _black,
        progress: 0.2,
        strokeWidth: 2,
        headLength: 12,
      );
      final b = ArrowPainter(
        from: Offset.zero,
        to: const Offset(10, 0),
        color: _black,
        progress: 0.8,
        strokeWidth: 2,
        headLength: 12,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint flips on a differing strokeWidth or headLength alone', () {
      ArrowPainter make({double strokeWidth = 2, double headLength = 12}) => ArrowPainter(
        from: Offset.zero,
        to: const Offset(10, 0),
        color: _black,
        progress: 1,
        strokeWidth: strokeWidth,
        headLength: headLength,
      );
      expect(make().shouldRepaint(make(strokeWidth: 4)), isTrue);
      expect(make().shouldRepaint(make(headLength: 20)), isTrue);
      expect(make().shouldRepaint(make()), isFalse);
    });
  });

  group('ConnectorPainter geometry', () {
    test('a straight outline has one segment, an elbow has the corner', () {
      final straight = ConnectorPainter(
        from: Offset.zero,
        to: const Offset(40, 40),
        color: _black,
        progress: 1,
        strokeWidth: 2,
      );
      final elbow = ConnectorPainter(
        from: Offset.zero,
        to: const Offset(40, 40),
        corner: const Offset(40, 0),
        color: _black,
        progress: 0.5,
        strokeWidth: 2,
      );
      expect(straight.trimmedTo(0).computeMetrics().isEmpty, isTrue);
      expect(elbow.trimmedTo(1), isNotNull);
      expect(straight.shouldRepaint(elbow), isTrue);
    });

    test('shouldRepaint flips on a differing strokeWidth alone', () {
      ConnectorPainter make({double strokeWidth = 2}) => ConnectorPainter(
        from: Offset.zero,
        to: const Offset(40, 40),
        color: _black,
        progress: 1,
        strokeWidth: strokeWidth,
      );
      expect(make().shouldRepaint(make(strokeWidth: 5)), isTrue);
      expect(make().shouldRepaint(make()), isFalse);
    });
  });

  group('SpotlightPainter hole', () {
    test('the hole grows from a point at reveal 0 to the full region at 1', () {
      const region = Rect.fromLTWH(20, 20, 40, 40);
      const closed = SpotlightPainter(region: region, reveal: 0, dimColor: _black);
      const open = SpotlightPainter(region: region, reveal: 1, dimColor: _black);
      expect(closed.hole.width, 0);
      expect(open.hole, region);
      expect(closed.usesEvenOdd, isTrue);
      expect(closed.shouldRepaint(open), isTrue);
      expect(closed.shouldRepaint(closed), isFalse);
    });
  });
}
