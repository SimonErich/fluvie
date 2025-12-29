import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/helpers/helpers.dart';
import 'package:fluvie/src/declarative/animations/animations.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

/// Helper function to wrap test widgets with necessary ancestors
Widget wrapWithApp(Widget child, {int frame = 0}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1080, 1920)),
      child: VideoComposition(
        fps: 30,
        durationInFrames: 300,
        width: 1080,
        height: 1920,
        child: FrameProvider(frame: frame, child: child),
      ),
    ),
  );
}

void main() {
  group('FloatingElement', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(FloatingElement(child: Container(key: const Key('child')))),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('applies transform', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          FloatingElement(
            position: const Offset(100, 200),
            child: Container(key: const Key('child')),
          ),
        ),
      );

      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('withRotation constructor applies rotation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const FloatingElement.withRotation(
            rotationDegrees: 5,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('animation changes with frame', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(0, 20),
            floatFrequency: 1.0,
            child: SizedBox(width: 100, height: 100),
          ),
          frame: 0,
        ),
      );

      final transform1 = tester.widget<Transform>(find.byType(Transform).last);

      await tester.pumpWidget(
        wrapWithApp(
          const FloatingElement(
            floatAmplitude: Offset(0, 20),
            floatFrequency: 1.0,
            child: SizedBox(width: 100, height: 100),
          ),
          frame: 15,
        ),
      );

      final transform2 = tester.widget<Transform>(find.byType(Transform).last);

      // Transforms should be different at different frames
      expect(transform1.transform, isNot(equals(transform2.transform)));
    });
  });

  group('PolaroidFrame', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(PolaroidFrame(child: Container(key: const Key('child')))),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('renders caption when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const PolaroidFrame(
            caption: 'Summer 2024',
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.text('Summer 2024'), findsOneWidget);
    });

    testWidgets('does not render caption when null', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const PolaroidFrame(child: SizedBox(width: 100, height: 100)),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('tilted constructor applies rotation', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const PolaroidFrame.tilted(
            tiltDegrees: 10,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('respects size parameter', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const PolaroidFrame(
            size: Size(400, 500),
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 400);
      expect(container.constraints?.maxHeight, 500);
    });
  });

  group('StatCard', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const StatCard(
            value: 42,
            label: 'Photos',
            startFrame: 0,
            countDuration: 1,
          ),
          frame: 1,
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('renders sublabel when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Score',
            sublabel: 'This Month',
            startFrame: 0,
            countDuration: 1,
          ),
          frame: 1,
        ),
      );

      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets('shows animated count', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Count',
            startFrame: 0,
            countDuration: 60,
            countCurve: Curves.linear,
          ),
          frame: 0,
        ),
      );

      expect(find.text('0'), findsOneWidget);

      await tester.pumpWidget(
        wrapWithApp(
          const StatCard(
            value: 100,
            label: 'Count',
            startFrame: 0,
            countDuration: 60,
            countCurve: Curves.linear,
          ),
          frame: 60,
        ),
      );

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('percentage constructor formats correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const StatCard.percentage(
            value: 75,
            label: 'Progress',
            startFrame: 0,
            countDuration: 1,
          ),
          frame: 1,
        ),
      );

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('currency constructor formats correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          StatCard.currency(
            value: 500,
            label: 'Savings',
            startFrame: 0,
            countDuration: 1,
          ),
          frame: 1,
        ),
      );

      expect(find.text('\$500'), findsOneWidget);
    });

    testWidgets('currency with custom symbol', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          StatCard.currency(
            value: 100,
            label: 'Price',
            currencySymbol: '€',
            startFrame: 0,
            countDuration: 1,
          ),
          frame: 1,
        ),
      );

      expect(find.text('€100'), findsOneWidget);
    });
  });

  group('Collage', () {
    testWidgets('grid2x2 renders children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.grid2x2(
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
              Container(key: const Key('child3')),
              Container(key: const Key('child4')),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
      expect(find.byKey(const Key('child3')), findsOneWidget);
      expect(find.byKey(const Key('child4')), findsOneWidget);
    });

    testWidgets('grid3x3 renders children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.grid3x3(
            children: List.generate(9, (i) => Container(key: Key('child$i'))),
          ),
        ),
      );

      for (int i = 0; i < 9; i++) {
        expect(find.byKey(Key('child$i')), findsOneWidget);
      }
    });

    testWidgets('splitHorizontal renders left and right', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.splitHorizontal(
            left: Container(key: const Key('left')),
            right: Container(key: const Key('right')),
          ),
        ),
      );

      expect(find.byKey(const Key('left')), findsOneWidget);
      expect(find.byKey(const Key('right')), findsOneWidget);
    });

    testWidgets('splitVertical renders top and bottom', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.splitVertical(
            top: Container(key: const Key('top')),
            bottom: Container(key: const Key('bottom')),
          ),
        ),
      );

      expect(find.byKey(const Key('top')), findsOneWidget);
      expect(find.byKey(const Key('bottom')), findsOneWidget);
    });

    testWidgets('featured renders main and thumbnails', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.featured(
            main: Container(key: const Key('main')),
            thumbnails: [
              Container(key: const Key('thumb1')),
              Container(key: const Key('thumb2')),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('main')), findsOneWidget);
      expect(find.byKey(const Key('thumb1')), findsOneWidget);
      expect(find.byKey(const Key('thumb2')), findsOneWidget);
    });

    testWidgets('applies entry animation when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.grid2x2(
            entryAnimation: PropAnimation.slideUp(),
            staggerDelay: 5,
            animationDuration: 20,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
          frame: 30, // After animation
        ),
      );

      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
    });

    testWidgets('applies border radius when specified', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Collage.grid2x2(
            itemBorderRadius: 16,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });
  });
}
