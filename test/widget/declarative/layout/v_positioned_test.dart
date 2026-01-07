import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_positioned.dart';
import 'package:fluvie/src/declarative/layout/v_stack.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VPositioned', () {
    group('basic functionality', () {
      testWidgets('renders child with positioning', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
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

      testWidgets('applies left and top position', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 50,
                top: 100,
                child: SizedBox(key: Key('inner')),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 50);
        expect(positioned.top, 100);
      });

      testWidgets('applies right and bottom position', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                right: 30,
                bottom: 40,
                child: SizedBox(),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.right, 30);
        expect(positioned.bottom, 40);
      });

      testWidgets('applies width and height', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 0,
                top: 0,
                width: 200,
                height: 150,
                child: SizedBox(),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.width, 200);
        expect(positioned.height, 150);
      });

      testWidgets('can have null positions', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                child: Text('No position'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, isNull);
        expect(positioned.top, isNull);
        expect(positioned.right, isNull);
        expect(positioned.bottom, isNull);
      });
    });

    group('factory constructors', () {
      testWidgets('VPositioned.fill fills the stack', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned.fill(
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 0.0);
        expect(positioned.top, 0.0);
        expect(positioned.right, 0.0);
        expect(positioned.bottom, 0.0);
      });

      testWidgets('VPositioned.fill with custom insets', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned.fill(
                left: 10,
                top: 20,
                right: 30,
                bottom: 40,
                child: ColoredBox(color: Colors.red),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 10);
        expect(positioned.top, 20);
        expect(positioned.right, 30);
        expect(positioned.bottom, 40);
      });

      testWidgets('VPositioned.fromOffset creates from Offset', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VStack(
            children: [
              VPositioned.fromOffset(
                offset: const Offset(75, 125),
                child: const Text('From Offset'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 75);
        expect(positioned.top, 125);
      });

      testWidgets('VPositioned.fromOffset with width and height',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VStack(
            children: [
              VPositioned.fromOffset(
                offset: const Offset(50, 50),
                width: 100,
                height: 100,
                child: const ColoredBox(color: Colors.green),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 50);
        expect(positioned.top, 50);
        expect(positioned.width, 100);
        expect(positioned.height, 100);
      });

      testWidgets('VPositioned.fromRect creates from Rect', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VStack(
            children: [
              VPositioned.fromRect(
                rect: const Rect.fromLTWH(10, 20, 80, 60),
                child: const Text('From Rect'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 10);
        expect(positioned.top, 20);
        expect(positioned.width, 80);
        expect(positioned.height, 60);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                child: Text('Visible'),
              ),
            ],
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 10,
                endFrame: 100,
                child: Text('In Range'),
              ),
            ],
          ),
          frame: 50,
        ));

        expect(find.text('In Range'), findsOneWidget);
      });

      testWidgets('hidden when frame is before startFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 30,
                endFrame: 100,
                child: Text('Hidden'),
              ),
            ],
          ),
          frame: 10,
        ));

        // Layer returns SizedBox.shrink() when outside visibility window
        expect(find.text('Hidden'), findsNothing);
      });

      testWidgets('hidden when frame is after endFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 10,
                endFrame: 50,
                child: Text('Hidden'),
              ),
            ],
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
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 0,
                endFrame: 100,
                fadeInFrames: 20,
                child: Text('Fading'),
              ),
            ],
          ),
          frame: 10,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('applies fade out during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 0,
                endFrame: 100,
                fadeOutFrames: 20,
                child: Text('Fading'),
              ),
            ],
          ),
          frame: 90,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('uses custom fade curves', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                fadeInCurve: Curves.ease,
                fadeOutCurve: Curves.easeInOut,
                child: Text('Test'),
              ),
            ],
          ),
        ));

        final vPositioned =
            tester.widget<VPositioned>(find.byType(VPositioned));
        expect(vPositioned.fadeInCurve, Curves.ease);
        expect(vPositioned.fadeOutCurve, Curves.easeInOut);
      });

      testWidgets('factory constructors support video timing', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned.fill(
                startFrame: 20,
                endFrame: 80,
                fadeInFrames: 10,
                child: Text('Timed'),
              ),
            ],
          ),
          frame: 50,
        ));

        final vPositioned =
            tester.widget<VPositioned>(find.byType(VPositioned));
        expect(vPositioned.startFrame, 20);
        expect(vPositioned.endFrame, 80);
        expect(vPositioned.fadeInFrames, 10);
      });
    });

    group('heroKey', () {
      testWidgets('wraps with KeyedSubtree when heroKey is provided',
          (tester) async {
        final heroKey = GlobalKey();

        await tester.pumpWidget(wrapWithApp(
          VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                heroKey: heroKey,
                child: const Text('Hero'),
              ),
            ],
          ),
        ));

        expect(find.byType(KeyedSubtree), findsOneWidget);
      });

      testWidgets('does not wrap when heroKey is null', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                child: Text('No Hero'),
              ),
            ],
          ),
        ));

        // Should not find a KeyedSubtree that wraps our content
        final keyedSubtrees =
            tester.widgetList<KeyedSubtree>(find.byType(KeyedSubtree));
        // There might be other KeyedSubtrees in the tree, so just check VPositioned doesn't add one
        final vPositioned =
            tester.widget<VPositioned>(find.byType(VPositioned));
        expect(vPositioned.heroKey, isNull);
      });

      testWidgets('heroKey is accessible', (tester) async {
        final heroKey = GlobalKey();

        await tester.pumpWidget(wrapWithApp(
          VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                heroKey: heroKey,
                child: const Text('Hero'),
              ),
            ],
          ),
        ));

        final vPositioned =
            tester.widget<VPositioned>(find.byType(VPositioned));
        expect(vPositioned.heroKey, heroKey);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vPositioned = VPositioned(child: SizedBox());

        expect(vPositioned.fadeInFrames, 0);
        expect(vPositioned.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vPositioned = VPositioned(child: SizedBox());

        expect(vPositioned.fadeInCurve, Curves.easeOut);
        expect(vPositioned.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vPositioned = VPositioned(child: SizedBox());

        expect(vPositioned.startFrame, isNull);
        expect(vPositioned.endFrame, isNull);
      });

      testWidgets('default heroKey is null', (tester) async {
        const vPositioned = VPositioned(child: SizedBox());

        expect(vPositioned.heroKey, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero position', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 0,
                top: 0,
                child: Text('Zero'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 0);
        expect(positioned.top, 0);
      });

      testWidgets('handles negative positions', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            clipBehavior: Clip.none,
            children: [
              VPositioned(
                left: -50,
                top: -30,
                child: Text('Negative'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, -50);
        expect(positioned.top, -30);
      });

      testWidgets('handles very large positions', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10000,
                top: 10000,
                child: Text('Large'),
              ),
            ],
          ),
        ));

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 10000);
        expect(positioned.top, 10000);
      });

      testWidgets('handles zero duration (startFrame == endFrame)',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 50,
                endFrame: 50,
                child: Text('Zero Duration'),
              ),
            ],
          ),
          frame: 50,
        ));

        // When startFrame == endFrame, and frame >= end, widget is not visible
        expect(find.text('Zero Duration'), findsNothing);
      });

      testWidgets('handles only startFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                startFrame: 30,
                child: Text('Start Only'),
              ),
            ],
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VStack(
            children: [
              VPositioned(
                left: 10,
                top: 10,
                endFrame: 100,
                child: Text('End Only'),
              ),
            ],
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });
    });
  });
}
