import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_column.dart';
import 'package:fluvie/src/declarative/layout/stagger_config.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VColumn', () {
    group('basic functionality', () {
      testWidgets('renders children vertically', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
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
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('renders empty children list', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(children: []),
        ));

        expect(find.byType(Column), findsOneWidget);
        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children, isEmpty);
      });

      testWidgets('uses default mainAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisAlignment, MainAxisAlignment.start);
      });

      testWidgets('uses default crossAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.crossAxisAlignment, CrossAxisAlignment.center);
      });

      testWidgets('respects custom mainAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
      });

      testWidgets('respects custom crossAxisAlignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      });

      testWidgets('respects mainAxisSize', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisSize, MainAxisSize.min);
      });

      testWidgets('respects verticalDirection', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            verticalDirection: VerticalDirection.up,
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.verticalDirection, VerticalDirection.up);
      });

      testWidgets('respects textDirection', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            textDirection: TextDirection.rtl,
            children: [Text('Test')],
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.textDirection, TextDirection.rtl);
      });
    });

    group('spacing', () {
      testWidgets('adds SizedBox between children when spacing > 0',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            spacing: 20,
            children: [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
        ));

        // Should have 2 SizedBox spacers between 3 children
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacers = sizedBoxes.where((sb) => sb.height == 20).toList();
        expect(spacers.length, 2);
      });

      testWidgets('no SizedBox when spacing is 0', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            spacing: 0,
            children: [
              Text('First'),
              Text('Second'),
            ],
          ),
        ));

        // Column should contain exactly the children provided
        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, 2);
      });

      testWidgets('handles single child with spacing', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            spacing: 20,
            children: [Text('Only')],
          ),
        ));

        // No spacers needed for single child
        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, 1);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            children: [Text('Visible')],
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
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
          const VColumn(
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
          const VColumn(
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
          const VColumn(
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
          const VColumn(
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
          const VColumn(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            fadeInCurve: Curves.easeIn,
            fadeOutCurve: Curves.easeOut,
            children: [Text('Test')],
          ),
        ));

        final vColumn = tester.widget<VColumn>(find.byType(VColumn));
        expect(vColumn.fadeInCurve, Curves.easeIn);
        expect(vColumn.fadeOutCurve, Curves.easeOut);
      });
    });

    group('stagger animations', () {
      testWidgets('applies stagger to children', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VColumn(
            stagger: StaggerConfig.slideUp(delay: 10),
            children: const [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
          frame: 50, // Well into the animation
        ));

        // All children should be visible after stagger completes
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);
      });

      testWidgets('stagger with fade in shows first child first',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VColumn(
            stagger: const StaggerConfig.fade(delay: 15, duration: 10),
            children: const [
              Text('First'),
              Text('Second'),
            ],
          ),
          frame: 30, // Both children should be visible
        ));

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
      });

      testWidgets('stagger with slideUp applies transform', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VColumn(
            stagger: StaggerConfig.slideUp(delay: 15, distance: 50),
            children: const [
              Text('Sliding'),
            ],
          ),
          frame: 5, // During animation
        ));

        // Transform.translate should be applied during animation
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('stagger with scale applies Transform.scale', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VColumn(
            stagger: StaggerConfig.scale(delay: 10, start: 0.5),
            children: const [
              SizedBox(width: 100, height: 100),
            ],
          ),
          frame: 5, // During animation
        ));

        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('stagger with spacing adds both transforms and spacers',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VColumn(
            spacing: 20,
            stagger: const StaggerConfig.fade(delay: 10),
            children: const [
              Text('First'),
              Text('Second'),
              Text('Third'),
            ],
          ),
          frame: 50, // After animation completes
        ));

        // Should have SizedBox spacers
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacers = sizedBoxes.where((sb) => sb.height == 20).toList();
        expect(spacers.length, 2);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vColumn = VColumn(children: [SizedBox()]);

        expect(vColumn.fadeInFrames, 0);
        expect(vColumn.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vColumn = VColumn(children: [SizedBox()]);

        expect(vColumn.fadeInCurve, Curves.easeOut);
        expect(vColumn.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vColumn = VColumn(children: [SizedBox()]);

        expect(vColumn.startFrame, isNull);
        expect(vColumn.endFrame, isNull);
      });

      testWidgets('default spacing is 0', (tester) async {
        const vColumn = VColumn(children: [SizedBox()]);

        expect(vColumn.spacing, 0);
      });

      testWidgets('default stagger is null', (tester) async {
        const vColumn = VColumn(children: [SizedBox()]);

        expect(vColumn.stagger, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero duration (startFrame == endFrame)',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            startFrame: 50,
            endFrame: 50,
            children: [Text('Zero Duration')],
          ),
          frame: 50,
        ));

        // When startFrame == endFrame, and frame >= end, widget is not visible
        expect(find.text('Zero Duration'), findsNothing);
      });

      testWidgets('handles only startFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            startFrame: 30,
            children: [Text('Start Only')],
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VColumn(
            endFrame: 100,
            children: [Text('End Only')],
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });

      testWidgets('handles large number of children', (tester) async {
        // Use mainAxisSize.min to avoid overflow with many children
        final children = List.generate(
          10,
          (i) => SizedBox(height: 20, child: Text('Item $i')),
        );

        await tester.pumpWidget(wrapWithApp(
          VColumn(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ));

        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 9'), findsOneWidget);
      });

      testWidgets('handles large spacing value', (tester) async {
        // Test that spacing property is correctly set without overflow
        const vColumn = VColumn(
          spacing: 1000,
          children: [
            SizedBox(),
            SizedBox(),
          ],
        );

        expect(vColumn.spacing, 1000);
      });
    });
  });
}
