import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_row.dart';
import 'package:fluvie/src/declarative/layout/stagger_config.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VRow', () {
    group('basic functionality', () {
      testWidgets('renders children horizontally', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            children: [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
        ));

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
      });

      testWidgets('renders empty children list', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(children: []),
        ));

        expect(find.byType(Row), findsOneWidget);
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children, isEmpty);
      });

      testWidgets('uses default mainAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisAlignment, MainAxisAlignment.start);
      });

      testWidgets('uses default crossAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      });

      testWidgets('respects custom mainAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisAlignment, MainAxisAlignment.spaceAround);
      });

      testWidgets('respects custom crossAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.end);
      });

      testWidgets('respects mainAxisSize', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, MainAxisSize.min);
      });

      testWidgets('respects textDirection', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            textDirection: TextDirection.rtl,
            children: [Text('Test')],
          ),
        ));

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.textDirection, TextDirection.rtl);
      });
    });

    group('spacing', () {
      testWidgets('adds SizedBox between children when spacing > 0',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            spacing: 15,
            children: [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
        ));

        // Should have 2 SizedBox spacers between 3 children (with width)
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacers = sizedBoxes.where((sb) => sb.width == 15).toList();
        expect(spacers.length, 2);
      });

      testWidgets('no SizedBox when spacing is 0', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            spacing: 0,
            children: [
              Text('First'),
              Text('Second'),
            ],
          ),
        ));

        // Row should contain exactly the children provided
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, 2);
      });

      testWidgets('handles single child with spacing', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            spacing: 20,
            children: [Text('Only')],
          ),
        ));

        // No spacers needed for single child
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, 1);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            children: [Text('Visible')],
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 10,
            endFrame: 100,
            children: [Text('In Range')],
          ),
          frame: 50,
        ));

        expect(find.text('In Range'), findsOneWidget);
      });

      testWidgets('hidden when frame is before startFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 30,
            endFrame: 100,
            children: [Text('Hidden')],
          ),
          frame: 10,
        ));

        // Layer returns SizedBox.shrink() when outside visibility window
        expect(find.text('Hidden'), findsNothing);
      });

      testWidgets('hidden when frame is after endFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 10,
            endFrame: 50,
            children: [Text('Hidden')],
          ),
          frame: 60,
        ));

        // Layer returns SizedBox.shrink() when outside visibility window
        expect(find.text('Hidden'), findsNothing);
      });
    });

    group('fade transitions', () {
      testWidgets('applies fade in during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            children: [Text('Fading')],
          ),
          frame: 10, // Halfway through fade in
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('applies fade out during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 0,
            endFrame: 100,
            fadeOutFrames: 20,
            children: [Text('Fading')],
          ),
          frame: 90, // During fade out
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('uses custom fade curves', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            fadeInCurve: Curves.bounceIn,
            fadeOutCurve: Curves.bounceOut,
            children: [Text('Test')],
          ),
        ));

        final vRow = tester.widget<VRow>(find.byType(VRow));
        expect(vRow.fadeInCurve, Curves.bounceIn);
        expect(vRow.fadeOutCurve, Curves.bounceOut);
      });
    });

    group('stagger animations', () {
      testWidgets('applies stagger to children', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VRow(
            stagger: StaggerConfig.slideLeft(delay: 10),
            children: const [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
          frame: 50, // Well into the animation
        ));

        // All children should be present after stagger completes
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);
      });

      testWidgets('stagger with slideRight applies transform', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VRow(
            stagger: StaggerConfig.slideRight(delay: 15, distance: 40),
            children: const [
              Text('Sliding'),
            ],
          ),
          frame: 5, // During animation
        ));

        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('stagger with spacing adds both transforms and spacers',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            spacing: 10,
            stagger: StaggerConfig.fade(delay: 10),
            children: [
              Text('First'),
              Text('Second'),
            ],
          ),
          frame: 50, // After animation completes
        ));

        // Should have SizedBox spacer (width)
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacers = sizedBoxes.where((sb) => sb.width == 10).toList();
        expect(spacers.length, 1);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vRow = VRow(children: [SizedBox()]);

        expect(vRow.fadeInFrames, 0);
        expect(vRow.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vRow = VRow(children: [SizedBox()]);

        expect(vRow.fadeInCurve, Curves.easeOut);
        expect(vRow.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vRow = VRow(children: [SizedBox()]);

        expect(vRow.startFrame, isNull);
        expect(vRow.endFrame, isNull);
      });

      testWidgets('default spacing is 0', (tester) async {
        const vRow = VRow(children: [SizedBox()]);

        expect(vRow.spacing, 0);
      });

      testWidgets('default stagger is null', (tester) async {
        const vRow = VRow(children: [SizedBox()]);

        expect(vRow.stagger, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero duration (startFrame == endFrame)',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 50,
            endFrame: 50,
            children: [Text('Zero Duration')],
          ),
          frame: 50,
        ));

        // When startFrame == endFrame, and frame >= end, widget is not visible
        // This is a zero-duration window that's never visible
        expect(find.text('Zero Duration'), findsNothing);
      });

      testWidgets('handles only startFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            startFrame: 30,
            children: [Text('Start Only')],
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VRow(
            endFrame: 100,
            children: [Text('End Only')],
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });

      testWidgets('handles large number of children', (tester) async {
        final children = List.generate(
          30,
          (i) => SizedBox(width: 10, child: Text('$i')),
        );

        await tester.pumpWidget(wrapWithApp(
          VRow(children: children),
        ));

        expect(find.text('0'), findsOneWidget);
        expect(find.text('29'), findsOneWidget);
      });
    });
  });
}
