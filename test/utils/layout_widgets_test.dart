import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/layout.dart';
import 'package:fluvie/src/presentation/video_composition.dart';

/// Helper function to wrap test widgets with necessary ancestors
Widget wrapWithApp(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: VideoComposition(
      fps: 30,
      durationInFrames: 100,
      width: 1080,
      height: 1920,
      child: child,
    ),
  );
}

void main() {
  group('VStack', () {
    testWidgets('renders children in a Stack', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VStack(
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
        ),
      );

      expect(find.byType(Stack), findsOneWidget);
      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
    });

    testWidgets('respects alignment property', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const VStack(
            alignment: Alignment.bottomRight,
            children: [SizedBox(width: 50, height: 50)],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.alignment, Alignment.bottomRight);
    });

    testWidgets('respects fit property', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const VStack(
            fit: StackFit.expand,
            children: [SizedBox(width: 50, height: 50)],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.fit, StackFit.expand);
    });
  });

  group('VPositioned', () {
    testWidgets('positions child with left and top', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VStack(
            children: [
              VPositioned(
                left: 100,
                top: 200,
                child: Container(key: const Key('child')),
              ),
            ],
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 100);
      expect(positioned.top, 200);
    });

    testWidgets('fill constructor sets all edges to 0', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VStack(
            children: [
              VPositioned.fill(child: Container(key: const Key('child'))),
            ],
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 0);
      expect(positioned.top, 0);
      expect(positioned.right, 0);
      expect(positioned.bottom, 0);
    });

    testWidgets('fromOffset constructor positions from offset', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VStack(
            children: [
              VPositioned.fromOffset(
                offset: const Offset(50, 75),
                child: Container(key: const Key('child')),
              ),
            ],
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 50);
      expect(positioned.top, 75);
    });
  });

  group('VRow', () {
    testWidgets('renders children in a Row', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VRow(
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
              Container(key: const Key('child3')),
            ],
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
      expect(find.byKey(const Key('child3')), findsOneWidget);
    });

    testWidgets('adds spacing between children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VRow(
            spacing: 20,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      // With 2 children and spacing, we expect 3 widgets: child, spacer, child
      expect(row.children.length, 3);
      expect(row.children[1], isA<SizedBox>());
      expect((row.children[1] as SizedBox).width, 20);
    });

    testWidgets('respects mainAxisAlignment', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const VRow(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [SizedBox(width: 50)],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
    });
  });

  group('VColumn', () {
    testWidgets('renders children in a Column', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VColumn(
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
              Container(key: const Key('child3')),
            ],
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byKey(const Key('child1')), findsOneWidget);
      expect(find.byKey(const Key('child2')), findsOneWidget);
      expect(find.byKey(const Key('child3')), findsOneWidget);
    });

    testWidgets('adds spacing between children', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VColumn(
            spacing: 15,
            children: [
              Container(key: const Key('child1')),
              Container(key: const Key('child2')),
            ],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.length, 3);
      expect(column.children[1], isA<SizedBox>());
      expect((column.children[1] as SizedBox).height, 15);
    });

    testWidgets('respects crossAxisAlignment', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const VColumn(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [SizedBox(height: 50)],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, CrossAxisAlignment.end);
    });
  });

  group('VCenter', () {
    testWidgets('centers its child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(VCenter(child: Container(key: const Key('child')))),
      );

      expect(find.byType(Center), findsOneWidget);
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('respects widthFactor and heightFactor', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VCenter(
            widthFactor: 0.5,
            heightFactor: 0.75,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final center = tester.widget<Center>(find.byType(Center));
      expect(center.widthFactor, 0.5);
      expect(center.heightFactor, 0.75);
    });
  });

  group('VPadding', () {
    testWidgets('adds padding around child', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VPadding(
            padding: const EdgeInsets.all(20),
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(20));
    });

    testWidgets('VPadding.all creates uniform padding', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VPadding.all(30, child: Container(key: const Key('child'))),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(30));
    });

    testWidgets('VPadding.symmetric creates symmetric padding', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VPadding.symmetric(
            horizontal: 10,
            vertical: 20,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      );
    });

    testWidgets('VPadding.only creates specific padding', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VPadding.only(
            left: 5,
            top: 10,
            right: 15,
            bottom: 20,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(
        padding.padding,
        const EdgeInsets.only(left: 5, top: 10, right: 15, bottom: 20),
      );
    });
  });

  group('VSizedBox', () {
    testWidgets('constrains child to width and height', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VSizedBox(
            width: 200,
            height: 100,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 200);
      expect(sizedBox.height, 100);
    });

    testWidgets('VSizedBox.square creates square box', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VSizedBox.square(
            dimension: 150,
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 150);
      expect(sizedBox.height, 150);
    });

    testWidgets('VSizedBox.expand creates expanding box', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VSizedBox.expand(child: Container(key: const Key('child'))),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, double.infinity);
      expect(sizedBox.height, double.infinity);
    });

    testWidgets('VSizedBox.shrink creates shrinking box', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VSizedBox.shrink(child: Container(key: const Key('child'))),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 0);
      expect(sizedBox.height, 0);
    });

    testWidgets('VSizedBox.fromSize creates box from Size', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          VSizedBox.fromSize(
            size: const Size(300, 400),
            child: Container(key: const Key('child')),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 300);
      expect(sizedBox.height, 400);
    });
  });

  group('StaggerConfig', () {
    test('calculates start frame for index', () {
      final config = StaggerConfig(delay: 15);
      expect(config.startFrameForIndex(0), 0);
      expect(config.startFrameForIndex(1), 15);
      expect(config.startFrameForIndex(2), 30);
      expect(config.startFrameForIndex(3), 45);
    });

    test('calculates end frame for index', () {
      final config = StaggerConfig(delay: 15, duration: 30);
      expect(config.endFrameForIndex(0), 30);
      expect(config.endFrameForIndex(1), 45);
      expect(config.endFrameForIndex(2), 60);
    });

    test('slideUp creates slide up config', () {
      final config = StaggerConfig.slideUp(delay: 10);
      expect(config.slideIn, true);
      expect(config.slideOffset.dy, greaterThan(0));
      expect(config.fadeIn, true);
    });

    test('slideDown creates slide down config', () {
      final config = StaggerConfig.slideDown(delay: 10);
      expect(config.slideIn, true);
      expect(config.slideOffset.dy, lessThan(0));
    });

    test('slideLeft creates slide left config', () {
      final config = StaggerConfig.slideLeft(delay: 10);
      expect(config.slideIn, true);
      expect(config.slideOffset.dx, greaterThan(0));
    });

    test('slideRight creates slide right config', () {
      final config = StaggerConfig.slideRight(delay: 10);
      expect(config.slideIn, true);
      expect(config.slideOffset.dx, lessThan(0));
    });

    test('scale creates scale config', () {
      final config = StaggerConfig.scale(delay: 10, start: 0.5);
      expect(config.scaleIn, true);
      expect(config.scaleStart, 0.5);
    });

    test('fade creates fade config', () {
      final config = StaggerConfig.fade(delay: 10);
      expect(config.fadeIn, true);
      expect(config.slideIn, false);
      expect(config.scaleIn, false);
    });

    test('calculates total duration for children', () {
      final config = StaggerConfig(delay: 15, duration: 30);
      expect(config.totalDuration(0), 0);
      expect(config.totalDuration(1), 30); // Just the animation duration
      expect(config.totalDuration(3), 60); // 2*15 + 30 = 60
      expect(config.totalDuration(5), 90); // 4*15 + 30 = 90
    });
  });

  group('VideoTimingDefaults', () {
    test('has expected default values', () {
      // Default fade frames are 0 (no automatic fade unless specified)
      expect(VideoTimingDefaults.fadeInFrames, 0);
      expect(VideoTimingDefaults.fadeOutFrames, 0);
      // Curves should be valid
      expect(VideoTimingDefaults.fadeInCurve, isA<Curve>());
      expect(VideoTimingDefaults.fadeOutCurve, isA<Curve>());
    });
  });
}
