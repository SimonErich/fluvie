import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/animations/core/stagger.dart';
import 'package:fluvie/src/declarative/animations/core/prop_animation.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('Stagger', () {
    group('construction', () {
      test('creates with required children', () {
        const widget = Stagger(
          children: [SizedBox(), SizedBox()],
        );

        expect(widget.children.length, 2);
      });

      test('has default values', () {
        const widget = Stagger(children: []);

        expect(widget.staggerDelay, 10);
        expect(widget.animationDuration, 30);
        expect(widget.curve, Curves.easeOut);
        expect(widget.direction, Axis.vertical);
        expect(widget.spacing, 0);
        expect(widget.mainAxisAlignment, MainAxisAlignment.start);
        expect(widget.crossAxisAlignment, CrossAxisAlignment.center);
        expect(widget.mainAxisSize, MainAxisSize.min);
      });

      test('accepts custom values', () {
        const widget = Stagger(
          children: [],
          staggerDelay: 15,
          animationDuration: 45,
          curve: Curves.bounceOut,
          direction: Axis.horizontal,
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
        );

        expect(widget.staggerDelay, 15);
        expect(widget.animationDuration, 45);
        expect(widget.curve, Curves.bounceOut);
        expect(widget.direction, Axis.horizontal);
        expect(widget.spacing, 10);
        expect(widget.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
        expect(widget.crossAxisAlignment, CrossAxisAlignment.start);
        expect(widget.mainAxisSize, MainAxisSize.max);
      });
    });

    group('Stagger.vertical', () {
      test('creates with vertical direction', () {
        const widget = Stagger.vertical(children: []);
        expect(widget.direction, Axis.vertical);
      });

      test('has vertical slide animation by default', () {
        const widget = Stagger.vertical(children: []);
        expect(widget.animation, isA<TranslateAnimation>());
        final translate = widget.animation as TranslateAnimation;
        expect(translate.start.dy, 30);
        expect(translate.start.dx, 0);
      });
    });

    group('Stagger.horizontal', () {
      test('creates with horizontal direction', () {
        const widget = Stagger.horizontal(children: []);
        expect(widget.direction, Axis.horizontal);
      });

      test('has horizontal slide animation by default', () {
        const widget = Stagger.horizontal(children: []);
        expect(widget.animation, isA<TranslateAnimation>());
        final translate = widget.animation as TranslateAnimation;
        expect(translate.start.dx, 30);
        expect(translate.start.dy, 0);
      });
    });

    group('Stagger.slideUpFade', () {
      test('creates combined animation', () {
        final widget = Stagger.slideUpFade(
          children: const [SizedBox()],
        );
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('accepts custom distance', () {
        final widget = Stagger.slideUpFade(
          distance: 50,
          children: const [SizedBox()],
        );
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('respects timing parameters', () {
        final widget = Stagger.slideUpFade(
          staggerDelay: 20,
          animationDuration: 60,
          children: const [SizedBox()],
        );
        expect(widget.staggerDelay, 20);
        expect(widget.animationDuration, 60);
      });
    });

    group('Stagger.scaleFade', () {
      test('creates combined animation', () {
        final widget = Stagger.scaleFade(
          children: const [SizedBox()],
        );
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('accepts custom startScale', () {
        final widget = Stagger.scaleFade(
          startScale: 0.5,
          children: const [SizedBox()],
        );
        expect(widget.animation, isA<CombinedAnimation>());
      });

      test('respects direction parameter', () {
        final widget = Stagger.scaleFade(
          direction: Axis.horizontal,
          children: const [SizedBox()],
        );
        expect(widget.direction, Axis.horizontal);
      });
    });

    group('totalDuration', () {
      test('returns 0 for empty children', () {
        const widget = Stagger(children: []);
        expect(widget.totalDuration, 0);
      });

      test('returns animationDuration for single child', () {
        const widget = Stagger(
          animationDuration: 30,
          children: [SizedBox()],
        );
        expect(widget.totalDuration, 30);
      });

      test('calculates correctly for multiple children', () {
        const widget = Stagger(
          staggerDelay: 10,
          animationDuration: 30,
          children: [SizedBox(), SizedBox(), SizedBox()],
        );
        // (3 - 1) * 10 + 30 = 50
        expect(widget.totalDuration, 50);
      });

      test('calculates correctly with different delay', () {
        const widget = Stagger(
          staggerDelay: 5,
          animationDuration: 20,
          children: [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
        );
        // (4 - 1) * 5 + 20 = 35
        expect(widget.totalDuration, 35);
      });
    });

    group('widget rendering', () {
      testWidgets('renders all children', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            children: [
              Text('Child 1'),
              Text('Child 2'),
              Text('Child 3'),
            ],
          ),
        ));

        expect(find.text('Child 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
        expect(find.text('Child 3'), findsOneWidget);
      });

      testWidgets('vertical stagger creates Column', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger.vertical(
            children: [
              Text('A'),
              Text('B'),
            ],
          ),
        ));

        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('horizontal stagger creates Row', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger.horizontal(
            children: [
              Text('A'),
              Text('B'),
            ],
          ),
        ));

        expect(find.byType(Row), findsOneWidget);
      });

      testWidgets('adds spacing between children', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            spacing: 20,
            children: [
              Text('A'),
              Text('B'),
            ],
          ),
        ));

        // Should find SizedBox for spacing
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('renders at different frames', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            staggerDelay: 10,
            animationDuration: 30,
            children: [
              Text('Item 1'),
              Text('Item 2'),
              Text('Item 3'),
            ],
          ),
          frame: 15,
        ));

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('renders correctly after all animations complete',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            staggerDelay: 10,
            animationDuration: 30,
            children: [
              Text('Final 1'),
              Text('Final 2'),
            ],
          ),
          frame: 100,
        ));

        expect(find.text('Final 1'), findsOneWidget);
        expect(find.text('Final 2'), findsOneWidget);
      });
    });

    group('alignment', () {
      testWidgets('applies mainAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Centered'),
            ],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisAlignment, MainAxisAlignment.center);
      });

      testWidgets('applies crossAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('End'),
            ],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.crossAxisAlignment, CrossAxisAlignment.end);
      });

      testWidgets('applies mainAxisSize', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text('Max'),
            ],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisSize, MainAxisSize.max);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty children list', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(children: []),
        ));

        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('handles single child', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            children: [Text('Single')],
          ),
        ));

        expect(find.text('Single'), findsOneWidget);
      });

      testWidgets('handles zero stagger delay', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            staggerDelay: 0,
            children: [
              Text('A'),
              Text('B'),
            ],
          ),
        ));

        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
      });

      testWidgets('handles zero animation duration', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            animationDuration: 0,
            children: [
              Text('A'),
              Text('B'),
            ],
          ),
        ));

        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
      });

      testWidgets('handles large number of children', (tester) async {
        final children = List.generate(
          20,
          (i) => Text('Item $i'),
        );

        await tester.pumpWidget(wrapWithApp(
          Stagger(children: children),
        ));

        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 19'), findsOneWidget);
      });
    });

    group('animation types', () {
      testWidgets('works with fadeIn animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          Stagger(
            animation: PropAnimation.fadeIn(),
            children: const [Text('Fade')],
          ),
          frame: 30, // Render at end of animation so fadeIn is visible
        ));

        expect(find.text('Fade'), findsOneWidget);
      });

      testWidgets('works with zoomIn animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          Stagger(
            animation: PropAnimation.zoomIn(),
            children: const [Text('Zoom')],
          ),
        ));

        expect(find.text('Zoom'), findsOneWidget);
      });

      testWidgets('works with combined animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          Stagger(
            animation: PropAnimation.combine([
              PropAnimation.slideUp(),
              PropAnimation.fadeIn(),
              PropAnimation.zoomIn(),
            ]),
            children: const [Text('Combined')],
          ),
          frame:
              30, // Render at end of animation so combined effects are visible
        ));

        expect(find.text('Combined'), findsOneWidget);
      });
    });

    group('curves', () {
      testWidgets('applies easeIn curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            curve: Curves.easeIn,
            children: [Text('EaseIn')],
          ),
        ));

        expect(find.text('EaseIn'), findsOneWidget);
      });

      testWidgets('applies bounceOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            curve: Curves.bounceOut,
            children: [Text('Bounce')],
          ),
        ));

        expect(find.text('Bounce'), findsOneWidget);
      });

      testWidgets('applies elasticOut curve', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const Stagger(
            curve: Curves.elasticOut,
            children: [Text('Elastic')],
          ),
        ));

        expect(find.text('Elastic'), findsOneWidget);
      });
    });
  });
}
