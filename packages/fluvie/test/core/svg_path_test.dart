import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show pathFromSvg;

void main() {
  test('M and L draw straight segments', () {
    final path = pathFromSvg('M 0 0 L 100 0');
    final metrics = path.computeMetrics().toList();
    expect(metrics, hasLength(1));
    expect(metrics.single.length, closeTo(100, 1e-6));
  });

  test('Z closes the subpath', () {
    final path = pathFromSvg('M 0 0 L 100 0 L 100 100 Z');
    final perimeter = path.computeMetrics().single.length;
    expect(perimeter, closeTo(200 + 141.4213562, 1e-3));
  });

  test('H and V draw axis-aligned lines from the current point', () {
    final path = pathFromSvg('M 10 20 H 110 V 120');
    final bounds = path.getBounds();
    expect(bounds, const Rect.fromLTRB(10, 20, 110, 120));
    expect(path.computeMetrics().single.length, closeTo(200, 1e-6));
  });

  test('C and Q curves land on their end points', () {
    Offset endOf(String data) {
      final metric = pathFromSvg(data).computeMetrics().single;
      return metric.getTangentForOffset(metric.length)!.position;
    }

    final cubicEnd = endOf('M 0 0 C 0 50 100 50 100 0');
    expect(cubicEnd.dx, closeTo(100, 1e-6));
    expect(cubicEnd.dy, closeTo(0, 1e-6));
    final quadEnd = endOf('M 0 0 Q 50 100 100 0');
    expect(quadEnd.dx, closeTo(100, 1e-6));
    expect(quadEnd.dy, closeTo(0, 1e-6));
  });

  test('commas and negative numbers parse', () {
    final path = pathFromSvg('M -10,-10 L 10,10');
    expect(path.getBounds(), const Rect.fromLTRB(-10, -10, 10, 10));
  });

  test('a second M starts a new subpath', () {
    final path = pathFromSvg('M 0 0 L 10 0 M 20 0 L 30 0');
    expect(path.computeMetrics().length, 2);
  });

  test('malformed data throws a FormatException naming the problem', () {
    expect(() => pathFromSvg(''), throwsFormatException);
    expect(() => pathFromSvg('M 0'), throwsFormatException);
    expect(() => pathFromSvg('X 0 0'), throwsFormatException);
    expect(() => pathFromSvg('L 10 10'), throwsFormatException);
    expect(() => pathFromSvg('M 0 0 L ten 10'), throwsFormatException);
  });
}
