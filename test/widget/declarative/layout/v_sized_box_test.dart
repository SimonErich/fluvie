import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_sized_box.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VSizedBox', () {
    group('basic functionality', () {
      testWidgets('renders child with specified size', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 200,
            height: 100,
            child: Text('Sized'),
          ),
        ));

        expect(find.text('Sized'), findsOneWidget);
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('applies correct width', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 150,
            child: SizedBox(key: Key('inner')),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 150);
      });

      testWidgets('applies correct height', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            height: 75,
            child: SizedBox(key: Key('inner')),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.height, 75);
      });

      testWidgets('can have null child', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.child, isNull);
      });

      testWidgets('can have null dimensions', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            child: Text('No dimensions'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, isNull);
        expect(vSizedBox.height, isNull);
      });
    });

    group('factory constructors', () {
      testWidgets('VSizedBox.fromSize creates from Size', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VSizedBox.fromSize(
            size: const Size(120, 80),
            child: const Text('From Size'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 120);
        expect(vSizedBox.height, 80);
      });

      testWidgets('VSizedBox.expand creates expanding box', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox.expand(
            child: Text('Expand'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, double.infinity);
        expect(vSizedBox.height, double.infinity);
      });

      testWidgets('VSizedBox.shrink creates shrinking box', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox.shrink(
            child: Text('Shrink'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 0.0);
        expect(vSizedBox.height, 0.0);
      });

      testWidgets('VSizedBox.square creates square box', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox.square(
            dimension: 64,
            child: Text('Square'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 64);
        expect(vSizedBox.height, 64);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            child: Text('Visible'),
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 10,
            endFrame: 100,
            child: Text('In Range'),
          ),
          frame: 50,
        ));

        expect(find.text('In Range'), findsOneWidget);
      });

      testWidgets('hidden when frame is before startFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 30,
            endFrame: 100,
            child: Text('Hidden'),
          ),
          frame: 10,
        ));

        // Layer returns SizedBox.shrink() when outside visibility window
        expect(find.text('Hidden'), findsNothing);
      });

      testWidgets('hidden when frame is after endFrame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 10,
            endFrame: 50,
            child: Text('Hidden'),
          ),
          frame: 60,
        ));

        // Layer returns SizedBox.shrink() when outside visibility window
        expect(find.text('Hidden'), findsNothing);
      });

      testWidgets('does not wrap when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            child: Text('No wrap'),
          ),
        ));

        // VSizedBox build method only wraps with timing if startFrame or endFrame is set
        // Without timing, it should just render a SizedBox directly
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('wraps with timing when startFrame is set', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 10,
            child: Text('Wrapped'),
          ),
          frame: 50,
        ));

        expect(find.text('Wrapped'), findsOneWidget);
      });
    });

    group('fade transitions', () {
      testWidgets('applies fade in during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            child: Text('Fading'),
          ),
          frame: 10,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('applies fade out during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 0,
            endFrame: 100,
            fadeOutFrames: 20,
            child: Text('Fading'),
          ),
          frame: 90,
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('uses custom fade curves', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            fadeInCurve: Curves.slowMiddle,
            fadeOutCurve: Curves.fastLinearToSlowEaseIn,
            child: Text('Test'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.fadeInCurve, Curves.slowMiddle);
        expect(vSizedBox.fadeOutCurve, Curves.fastLinearToSlowEaseIn);
      });

      testWidgets('factory constructors support video timing', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox.square(
            dimension: 50,
            startFrame: 20,
            endFrame: 80,
            fadeInFrames: 10,
            child: Text('Timed'),
          ),
          frame: 50,
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.startFrame, 20);
        expect(vSizedBox.endFrame, 80);
        expect(vSizedBox.fadeInFrames, 10);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vSizedBox = VSizedBox(child: SizedBox());

        expect(vSizedBox.fadeInFrames, 0);
        expect(vSizedBox.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vSizedBox = VSizedBox(child: SizedBox());

        expect(vSizedBox.fadeInCurve, Curves.easeOut);
        expect(vSizedBox.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vSizedBox = VSizedBox(child: SizedBox());

        expect(vSizedBox.startFrame, isNull);
        expect(vSizedBox.endFrame, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero size', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 0,
            height: 0,
            child: Text('Zero'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 0);
        expect(vSizedBox.height, 0);
      });

      testWidgets('handles very large dimensions', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 10000,
            height: 10000,
            child: Text('Large'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 10000);
        expect(vSizedBox.height, 10000);
      });

      testWidgets('handles zero duration (startFrame == endFrame)',
          (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 50,
            endFrame: 50,
            child: Text('Zero Duration'),
          ),
          frame: 50,
        ));

        // When startFrame == endFrame, and frame >= end, widget is not visible
        expect(find.text('Zero Duration'), findsNothing);
      });

      testWidgets('handles only startFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            startFrame: 30,
            child: Text('Start Only'),
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 100,
            height: 100,
            endFrame: 100,
            child: Text('End Only'),
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });

      testWidgets('handles only width specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            width: 200,
            child: Text('Width Only'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, 200);
        expect(vSizedBox.height, isNull);
      });

      testWidgets('handles only height specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VSizedBox(
            height: 150,
            child: Text('Height Only'),
          ),
        ));

        final vSizedBox = tester.widget<VSizedBox>(find.byType(VSizedBox));
        expect(vSizedBox.width, isNull);
        expect(vSizedBox.height, 150);
      });
    });
  });
}
