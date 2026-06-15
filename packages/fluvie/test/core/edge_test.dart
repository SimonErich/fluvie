import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/edge.dart';

void main() {
  group('Edge', () {
    test('entering from the bottom starts one element-size below: (0, 1)', () {
      expect(Edge.bottom.dx, 0.0);
      expect(Edge.bottom.dy, 1.0);
    });

    test('entering from the top starts one element-size above: (0, -1)', () {
      expect(Edge.top.dx, 0.0);
      expect(Edge.top.dy, -1.0);
    });

    test('entering from the left starts one element-size to the left: (-1, 0)', () {
      expect(Edge.left.dx, -1.0);
      expect(Edge.left.dy, 0.0);
    });

    test('entering from the right starts one element-size to the right: (1, 0)', () {
      expect(Edge.right.dx, 1.0);
      expect(Edge.right.dy, 0.0);
    });

    test('every edge offsets along exactly one axis by one element-size', () {
      for (final edge in Edge.values) {
        expect(edge.dx.abs() + edge.dy.abs(), 1.0, reason: '$edge');
      }
    });

    test('has exactly the four spec edges', () {
      expect(Edge.values, [Edge.top, Edge.bottom, Edge.left, Edge.right]);
    });
  });
}
