import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/keyframe_applier.dart';
import 'package:fluvie/src/core/keyframe.dart';

void main() {
  const child = SizedBox(key: Key('subject'), width: 10, height: 10);

  Future<void> pump(WidgetTester tester, Keyframe keyframe) =>
      tester.pumpWidget(applyKeyframe(keyframe, child));

  Matrix4 transformMatrix(WidgetTester tester) =>
      tester.widget<Transform>(find.byType(Transform)).transform;

  testWidgets('x: 1 mounts FractionalTranslation(Offset(1, 0))', (tester) async {
    await pump(tester, const Keyframe(x: 1));
    final widget = tester.widget<FractionalTranslation>(find.byType(FractionalTranslation));
    expect(widget.translation, const Offset(1, 0));
  });

  testWidgets('opacity 0.3 mounts Opacity(0.3)', (tester) async {
    await pump(tester, const Keyframe(opacity: 0.3));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.3);
  });

  testWidgets('scale 2 + scaleX 1.5 multiply to sx 3.0', (tester) async {
    await pump(tester, const Keyframe(scale: 2, scaleX: 1.5));
    final matrix = transformMatrix(tester);
    expect(matrix.storage[0], closeTo(3.0, 1e-12)); // sx
    expect(matrix.storage[5], closeTo(2.0, 1e-12)); // sy = scale * 1
  });

  testWidgets('rotation 0.25 turns is a 90-degree matrix', (tester) async {
    await pump(tester, const Keyframe(rotation: 0.25));
    final matrix = transformMatrix(tester);
    expect(matrix.storage[0], closeTo(0, 1e-12)); // cos(pi/2)
    expect(matrix.storage[1], closeTo(1, 1e-12)); // sin(pi/2)
    expect(matrix.storage[4], closeTo(-1, 1e-12));
    expect(matrix.storage[5], closeTo(0, 1e-12));
  });

  testWidgets('skewX in turns maps to the tangent shear entry', (tester) async {
    await pump(tester, const Keyframe(skewX: 0.125)); // 45 degrees
    final matrix = transformMatrix(tester);
    expect(matrix.storage[4], closeTo(math.tan(math.pi / 4), 1e-12));
  });

  testWidgets('origin reaches Transform.alignment', (tester) async {
    await pump(tester, const Keyframe(scale: 2, origin: Alignment.topLeft));
    final widget = tester.widget<Transform>(find.byType(Transform));
    expect(widget.alignment, Alignment.topLeft);
  });

  testWidgets('the natural keyframe wraps nothing', (tester) async {
    await pump(tester, Keyframe.natural);
    expect(find.byKey(const Key('subject')), findsOneWidget);
    expect(find.byType(Transform), findsNothing);
    expect(find.byType(FractionalTranslation), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('identity values wrap nothing either', (tester) async {
    await pump(tester, const Keyframe(scale: 1, rotation: 0, x: 0, y: 0, blur: 0));
    expect(find.byType(Transform), findsNothing);
    expect(find.byType(FractionalTranslation), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('blur mounts ImageFiltered', (tester) async {
    await pump(tester, const Keyframe(blur: 4));
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  testWidgets('wrap order is child-Transform-FractionalTranslation-ImageFiltered-Opacity', (
    tester,
  ) async {
    await pump(tester, const Keyframe(opacity: 0.5, x: 0.2, scale: 1.5, blur: 2));
    final opacity = find.byType(Opacity);
    final filtered = find.descendant(of: opacity, matching: find.byType(ImageFiltered));
    final fractional = find.descendant(
      of: filtered,
      matching: find.byType(FractionalTranslation),
    );
    final transform = find.descendant(of: fractional, matching: find.byType(Transform));
    expect(transform, findsOneWidget);
    expect(
      find.descendant(of: transform, matching: find.byKey(const Key('subject'))),
      findsOneWidget,
    );
  });

  testWidgets('a color-only keyframe wraps nothing (D9: color is data)', (tester) async {
    await pump(tester, const Keyframe(color: Color(0xFF112233)));
    expect(find.byKey(const Key('subject')), findsOneWidget);
    expect(find.byType(Transform), findsNothing);
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('overshot opacity is clamped into Opacity bounds', (tester) async {
    await pump(tester, const Keyframe(opacity: 1.08));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
  });
}
