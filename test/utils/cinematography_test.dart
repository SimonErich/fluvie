import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/cinematography/cinematography.dart';
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
  group('CameraFocus', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(CameraFocus(child: Container(key: const Key('child')))),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('applies zoom transform', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CameraFocus(
            zoomKeyframes: const {0: 1.0, 60: 2.0},
            child: Container(key: const Key('child')),
          ),
          frame: 30, // Halfway
        ),
      );

      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('applies position transform', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CameraFocus(
            positionKeyframes: const {0: Offset.zero, 60: Offset(100, 100)},
            child: Container(key: const Key('child')),
          ),
          frame: 30,
        ),
      );

      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('zoom constructor works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CameraFocus.zoom(
            startZoom: 1.0,
            endZoom: 1.5,
            startFrame: 0,
            endFrame: 60,
            child: Container(key: const Key('child')),
          ),
          frame: 30,
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('pan constructor works', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CameraFocus.pan(
            startPosition: Offset.zero,
            endPosition: const Offset(100, 50),
            startFrame: 0,
            endFrame: 60,
            child: Container(key: const Key('child')),
          ),
          frame: 30,
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('no transform when at default values', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          CameraFocus(
            zoomKeyframes: const {0: 1.0},
            child: Container(key: const Key('child')),
          ),
          frame: 0,
        ),
      );

      // Should not have any transforms (zoom = 1.0)
      expect(find.byKey(const Key('child')), findsOneWidget);
    });
  });

  group('Loop', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          Loop(loopDuration: 30, child: Container(key: const Key('child'))),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('provides local frame context', (tester) async {
      int? capturedLocalFrame;

      await tester.pumpWidget(
        wrapWithApp(
          Loop(
            loopDuration: 30,
            child: Builder(
              builder: (context) {
                capturedLocalFrame = context.loopFrame;
                return Container();
              },
            ),
          ),
          frame: 45, // Should be 15 in local frame (45 % 30)
        ),
      );

      expect(capturedLocalFrame, 15);
    });

    testWidgets('respects cycles limit', (tester) async {
      int? capturedLocalFrame;

      await tester.pumpWidget(
        wrapWithApp(
          Loop(
            loopDuration: 30,
            cycles: 2,
            child: Builder(
              builder: (context) {
                capturedLocalFrame = context.loopFrame;
                return Container();
              },
            ),
          ),
          frame: 90, // After 2 cycles (60 frames)
        ),
      );

      // Should be at final frame (29) since cycles completed
      expect(capturedLocalFrame, 29);
    });

    testWidgets('infinite loop continues', (tester) async {
      int? capturedLocalFrame;

      await tester.pumpWidget(
        wrapWithApp(
          Loop.infinite(
            loopDuration: 30,
            child: Builder(
              builder: (context) {
                capturedLocalFrame = context.loopFrame;
                return Container();
              },
            ),
          ),
          frame: 95, // Should be 5 in local frame (95 % 30)
        ),
      );

      expect(capturedLocalFrame, 5);
    });

    testWidgets('pingPong reverses on odd cycles', (tester) async {
      int? capturedLocalFrame;

      await tester.pumpWidget(
        wrapWithApp(
          Loop.pingPong(
            loopDuration: 30,
            child: Builder(
              builder: (context) {
                capturedLocalFrame = context.loopFrame;
                return Container();
              },
            ),
          ),
          frame: 45, // Cycle 1, frame 15 -> reversed: 29 - 15 = 14
        ),
      );

      expect(capturedLocalFrame, 14);
    });

    test('totalDuration calculates correctly', () {
      const loop = Loop(loopDuration: 30, cycles: 3, child: SizedBox());

      expect(loop.totalDuration, 90);
    });

    test('totalDuration is -1 for infinite', () {
      const loop = Loop.infinite(loopDuration: 30, child: SizedBox());

      expect(loop.totalDuration, -1);
    });
  });

  group('AnimatedChart', () {
    final testData = [
      const ChartData(label: 'A', value: 100),
      const ChartData(label: 'B', value: 150),
      const ChartData(label: 'C', value: 75),
    ];

    testWidgets('bar chart renders CustomPaint', (tester) async {
      await tester.pumpWidget(wrapWithApp(AnimatedChart.bar(data: testData)));

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('line chart renders CustomPaint', (tester) async {
      await tester.pumpWidget(wrapWithApp(AnimatedChart.line(data: testData)));

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('pie chart renders CustomPaint', (tester) async {
      await tester.pumpWidget(wrapWithApp(AnimatedChart.pie(data: testData)));

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('donut chart renders CustomPaint', (tester) async {
      await tester.pumpWidget(wrapWithApp(AnimatedChart.donut(data: testData)));

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('animation progresses with frame', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedChart.bar(
            data: testData,
            startFrame: 0,
            animationDuration: 60,
          ),
          frame: 0,
        ),
      );

      final paint1 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      await tester.pumpWidget(
        wrapWithApp(
          AnimatedChart.bar(
            data: testData,
            startFrame: 0,
            animationDuration: 60,
          ),
          frame: 30,
        ),
      );

      final paint2 = tester.widget<CustomPaint>(find.byType(CustomPaint));

      // Painters should be different due to progress change
      expect(paint1.painter, isNot(same(paint2.painter)));
    });

    testWidgets('respects custom colors', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          AnimatedChart.bar(
            data: testData,
            colors: const [
              Color(0xFFFF0000),
              Color(0xFF00FF00),
              Color(0xFF0000FF),
            ],
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });

  group('ChartData', () {
    test('creates with required fields', () {
      const data = ChartData(label: 'Test', value: 42);
      expect(data.label, 'Test');
      expect(data.value, 42);
      expect(data.color, isNull);
    });

    test('creates with optional color', () {
      const data = ChartData(
        label: 'Test',
        value: 42,
        color: Color(0xFFFF0000),
      );
      expect(data.color, const Color(0xFFFF0000));
    });
  });
}
