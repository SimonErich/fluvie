import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_stack.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VStack', () {
    group('basic functionality', () {
      testWidgets('renders children as overlay', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              ColoredBox(color: Colors.red, child: SizedBox(width: 100, height: 100)),
              Text('Overlay'),
            ],
          ),
        ));

        expect(find.byType(ColoredBox), findsOneWidget);
        expect(find.text('Overlay'), findsOneWidget);
        expect(find.byType(Stack), findsOneWidget);
      });

      testWidgets('renders empty children list', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(children: []),
        ));

        expect(find.byType(Stack), findsOneWidget);
        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.children, isEmpty);
      });

      testWidgets('uses default alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.alignment, AlignmentDirectional.topStart);
      });

      testWidgets('respects custom alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            alignment: Alignment.center,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.alignment, Alignment.center);
      });

      testWidgets('respects bottomRight alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            alignment: Alignment.bottomRight,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.alignment, Alignment.bottomRight);
      });

      testWidgets('uses default StackFit.loose', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.fit, StackFit.loose);
      });

      testWidgets('respects StackFit.expand', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            fit: StackFit.expand,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.fit, StackFit.expand);
      });

      testWidgets('respects StackFit.passthrough', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            fit: StackFit.passthrough,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.fit, StackFit.passthrough);
      });

      testWidgets('uses default clipBehavior', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.clipBehavior, Clip.hardEdge);
      });

      testWidgets('respects clipBehavior.none', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            clipBehavior: Clip.none,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.clipBehavior, Clip.none);
      });

      testWidgets('respects textDirection', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            textDirection: TextDirection.rtl,
            children: [SizedBox()],
          ),
        ));

        final stack = tester.widget<Stack>(find.byType(Stack));
        expect(stack.textDirection, TextDirection.rtl);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [Text('Visible')],
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
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
          const VStack(
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
          const VStack(
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
          const VStack(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            children: [Text('Fading')],
          ),
          frame: 10,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('applies fade out during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            startFrame: 0,
            endFrame: 100,
            fadeOutFrames: 20,
            children: [Text('Fading')],
          ),
          frame: 90,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('uses custom fade curves', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            fadeInCurve: Curves.elasticIn,
            fadeOutCurve: Curves.elasticOut,
            children: [Text('Test')],
          ),
        ));

        final vStack = tester.widget<VStack>(find.byType(VStack));
        expect(vStack.fadeInCurve, Curves.elasticIn);
        expect(vStack.fadeOutCurve, Curves.elasticOut);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vStack = VStack(children: [SizedBox()]);

        expect(vStack.fadeInFrames, 0);
        expect(vStack.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vStack = VStack(children: [SizedBox()]);

        expect(vStack.fadeInCurve, Curves.easeOut);
        expect(vStack.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vStack = VStack(children: [SizedBox()]);

        expect(vStack.startFrame, isNull);
        expect(vStack.endFrame, isNull);
      });
    });

    group('layering', () {
      testWidgets('children are rendered in order (first at bottom)', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              ColoredBox(
                key: Key('bottom'),
                color: Colors.red,
                child: SizedBox(width: 200, height: 200),
              ),
              ColoredBox(
                key: Key('top'),
                color: Colors.blue,
                child: SizedBox(width: 100, height: 100),
              ),
            ],
          ),
        ));

        expect(find.byKey(const Key('bottom')), findsOneWidget);
        expect(find.byKey(const Key('top')), findsOneWidget);
      });

      testWidgets('supports Positioned children', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              Positioned(
                left: 10,
                top: 20,
                child: Text('Positioned'),
              ),
            ],
          ),
        ));

        expect(find.text('Positioned'), findsOneWidget);
        expect(find.byType(Positioned), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero duration (startFrame == endFrame)', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
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
          const VStack(
            startFrame: 30,
            children: [Text('Start Only')],
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            endFrame: 100,
            children: [Text('End Only')],
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });

      testWidgets('handles many overlapping children', (tester) async {
        final children = List.generate(
          20,
          (i) => Container(
            key: Key('child_$i'),
            width: 100.0 - i * 2,
            height: 100.0 - i * 2,
            color: Colors.primaries[i % Colors.primaries.length],
          ),
        );

        await tester.pumpWidget(wrapWithApp(
          VStack(
            alignment: Alignment.center,
            children: children,
          ),
        ));

        expect(find.byKey(const Key('child_0')), findsOneWidget);
        expect(find.byKey(const Key('child_19')), findsOneWidget);
      });
    });
  });
}
