import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_padding.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VPadding', () {
    group('basic functionality', () {
      testWidgets('renders child with padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(20),
            child: Text('Padded'),
          ),
        ));

        expect(find.text('Padded'), findsOneWidget);
        expect(find.byType(Padding), findsOneWidget);
      });

      testWidgets('applies correct padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(16),
            child: SizedBox(key: Key('inner')),
          ),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, const EdgeInsets.all(16));
      });

      testWidgets('applies asymmetric padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.only(left: 10, top: 20, right: 30, bottom: 40),
            child: SizedBox(),
          ),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(
          padding.padding,
          const EdgeInsets.only(left: 10, top: 20, right: 30, bottom: 40),
        );
      });
    });

    group('factory constructors', () {
      testWidgets('VPadding.all creates uniform padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.all(
            24,
            child: const Text('All'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(vPadding.padding, const EdgeInsets.all(24));
      });

      testWidgets('VPadding.symmetric creates symmetric padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.symmetric(
            horizontal: 16,
            vertical: 8,
            child: const Text('Symmetric'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(
          vPadding.padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      });

      testWidgets('VPadding.symmetric with only horizontal', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.symmetric(
            horizontal: 20,
            child: const Text('Horizontal'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(
          vPadding.padding,
          const EdgeInsets.symmetric(horizontal: 20),
        );
      });

      testWidgets('VPadding.symmetric with only vertical', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.symmetric(
            vertical: 12,
            child: const Text('Vertical'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(
          vPadding.padding,
          const EdgeInsets.symmetric(vertical: 12),
        );
      });

      testWidgets('VPadding.only creates specific edge padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.only(
            left: 5,
            top: 10,
            right: 15,
            bottom: 20,
            child: const Text('Only'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(
          vPadding.padding,
          const EdgeInsets.only(left: 5, top: 10, right: 15, bottom: 20),
        );
      });

      testWidgets('VPadding.only with single edge', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.only(
            left: 30,
            child: const Text('Left Only'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(vPadding.padding, const EdgeInsets.only(left: 30));
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(10),
            child: Text('Visible'),
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(10),
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
          const VPadding(
            padding: EdgeInsets.all(10),
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
          const VPadding(
            padding: EdgeInsets.all(10),
            startFrame: 10,
            endFrame: 50,
            child: Text('Hidden'),
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
          const VPadding(
            padding: EdgeInsets.all(10),
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
          const VPadding(
            padding: EdgeInsets.all(10),
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
          const VPadding(
            padding: EdgeInsets.all(10),
            fadeInCurve: Curves.decelerate,
            fadeOutCurve: Curves.fastOutSlowIn,
            child: Text('Test'),
          ),
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(vPadding.fadeInCurve, Curves.decelerate);
        expect(vPadding.fadeOutCurve, Curves.fastOutSlowIn);
      });

      testWidgets('factory constructors support video timing', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          VPadding.all(
            10,
            startFrame: 20,
            endFrame: 80,
            fadeInFrames: 10,
            child: const Text('Timed'),
          ),
          frame: 50,
        ));

        final vPadding = tester.widget<VPadding>(find.byType(VPadding));
        expect(vPadding.startFrame, 20);
        expect(vPadding.endFrame, 80);
        expect(vPadding.fadeInFrames, 10);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vPadding = VPadding(
          padding: EdgeInsets.all(10),
          child: SizedBox(),
        );

        expect(vPadding.fadeInFrames, 0);
        expect(vPadding.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vPadding = VPadding(
          padding: EdgeInsets.all(10),
          child: SizedBox(),
        );

        expect(vPadding.fadeInCurve, Curves.easeOut);
        expect(vPadding.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vPadding = VPadding(
          padding: EdgeInsets.all(10),
          child: SizedBox(),
        );

        expect(vPadding.startFrame, isNull);
        expect(vPadding.endFrame, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero padding', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.zero,
            child: Text('Zero'),
          ),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, EdgeInsets.zero);
      });

      testWidgets('handles large padding values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(500),
            child: Text('Large'),
          ),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, const EdgeInsets.all(500));
      });

      testWidgets('handles zero duration (startFrame == endFrame)', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(10),
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
          const VPadding(
            padding: EdgeInsets.all(10),
            startFrame: 30,
            child: Text('Start Only'),
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VPadding(
            padding: EdgeInsets.all(10),
            endFrame: 100,
            child: Text('End Only'),
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });
    });
  });
}
