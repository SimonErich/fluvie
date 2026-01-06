import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/helpers/floating_element.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('FloatingElement', () {
    group('construction', () {
      test('creates with required child', () {
        const widget = FloatingElement(child: SizedBox());
        expect(widget.child, isA<SizedBox>());
      });

      test('has default values', () {
        const widget = FloatingElement(child: SizedBox());

        expect(widget.position, Offset.zero);
        expect(widget.floatAmplitude, const Offset(0, 10));
        expect(widget.floatFrequency, 0.5);
        expect(widget.floatPhase, 0.0);
        expect(widget.rotation, 0.0);
        expect(widget.rotationAmplitude, 0.0);
        expect(widget.showShadow, isFalse);
        expect(widget.shadowBlur, 10);
        expect(widget.shadowOffset, const Offset(0, 5));
        expect(widget.shadowColor, const Color(0x40000000));
      });

      test('accepts custom values', () {
        const widget = FloatingElement(
          child: SizedBox(),
          position: Offset(100, 200),
          floatAmplitude: Offset(5, 15),
          floatFrequency: 0.8,
          floatPhase: 0.5,
          rotation: 0.1,
          rotationAmplitude: 0.05,
          showShadow: true,
          shadowBlur: 20,
          shadowOffset: Offset(5, 10),
          shadowColor: Colors.black54,
        );

        expect(widget.position, const Offset(100, 200));
        expect(widget.floatAmplitude, const Offset(5, 15));
        expect(widget.floatFrequency, 0.8);
        expect(widget.floatPhase, 0.5);
        expect(widget.rotation, 0.1);
        expect(widget.rotationAmplitude, 0.05);
        expect(widget.showShadow, isTrue);
        expect(widget.shadowBlur, 20);
        expect(widget.shadowOffset, const Offset(5, 10));
        expect(widget.shadowColor, Colors.black54);
      });
    });

    group('factory constructor', () {
      test('withRotation creates with rotation amplitude', () {
        const widget = FloatingElement.withRotation(
          child: SizedBox(),
          rotationDegrees: 5.0,
        );

        // 5 degrees in radians
        expect(widget.rotationAmplitude, closeTo(5.0 * math.pi / 180, 0.001));
      });

      test('withRotation has different defaults', () {
        const widget = FloatingElement.withRotation(child: SizedBox());

        expect(widget.floatAmplitude, const Offset(0, 8));
        expect(widget.floatFrequency, 0.4);
      });

      test('withRotation accepts custom values', () {
        const widget = FloatingElement.withRotation(
          child: SizedBox(),
          position: Offset(50, 100),
          floatAmplitude: Offset(10, 20),
          rotationDegrees: 10.0,
          showShadow: true,
        );

        expect(widget.position, const Offset(50, 100));
        expect(widget.floatAmplitude, const Offset(10, 20));
        expect(widget.showShadow, isTrue);
      });
    });

    group('widget rendering', () {
      testWidgets('renders child', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            child: Text('Floating'),
          ),
        ));

        expect(find.text('Floating'), findsOneWidget);
      });

      testWidgets('applies translation transform', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            position: Offset(100, 200),
            child: Text('Positioned'),
          ),
        ));

        expect(find.text('Positioned'), findsOneWidget);
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('animates over different frames', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(0, 20),
            floatFrequency: 1.0,
            child: Text('Animated'),
          ),
          frame: 0,
        ));

        expect(find.text('Animated'), findsOneWidget);

        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(0, 20),
            floatFrequency: 1.0,
            child: Text('Animated'),
          ),
          frame: 15,
        ));

        expect(find.text('Animated'), findsOneWidget);
      });

      testWidgets('applies rotation when set', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            rotation: 0.5,
            child: Text('Rotated'),
          ),
        ));

        expect(find.text('Rotated'), findsOneWidget);
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('shows shadow when enabled', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            showShadow: true,
            shadowBlur: 15,
            child: Text('Shadow'),
          ),
        ));

        expect(find.text('Shadow'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('no shadow when disabled', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            showShadow: false,
            child: Text('NoShadow'),
          ),
        ));

        expect(find.text('NoShadow'), findsOneWidget);
      });
    });

    group('animation behavior', () {
      testWidgets('uses floatPhase for offset', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatPhase: 0.25,
            floatAmplitude: Offset(0, 10),
            child: Text('Phased'),
          ),
          frame: 0,
        ));

        expect(find.text('Phased'), findsOneWidget);
      });

      testWidgets('handles zero frequency', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatFrequency: 0.0,
            child: Text('Static'),
          ),
        ));

        expect(find.text('Static'), findsOneWidget);
      });

      testWidgets('handles high frequency', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatFrequency: 10.0,
            child: Text('Fast'),
          ),
        ));

        expect(find.text('Fast'), findsOneWidget);
      });

      testWidgets('handles zero amplitude', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset.zero,
            child: Text('NoFloat'),
          ),
        ));

        expect(find.text('NoFloat'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles negative position', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            position: Offset(-100, -200),
            child: Text('Negative'),
          ),
        ));

        expect(find.text('Negative'), findsOneWidget);
      });

      testWidgets('handles large amplitude', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(1000, 1000),
            child: Text('Large'),
          ),
        ));

        expect(find.text('Large'), findsOneWidget);
      });

      testWidgets('handles negative amplitude', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(-10, -10),
            child: Text('NegAmp'),
          ),
        ));

        expect(find.text('NegAmp'), findsOneWidget);
      });

      testWidgets('handles full rotation (2*pi)', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          FloatingElement(
            rotation: 2 * math.pi,
            child: const Text('FullRotation'),
          ),
        ));

        expect(find.text('FullRotation'), findsOneWidget);
      });
    });
  });
}
