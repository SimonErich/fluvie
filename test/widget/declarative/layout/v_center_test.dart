import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_center.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('VCenter', () {
    group('basic functionality', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            child: Text('Centered'),
          ),
        ));

        expect(find.text('Centered'), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('centers child horizontally and vertically', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            child: SizedBox(
              key: Key('box'),
              width: 100,
              height: 100,
            ),
          ),
        ));

        expect(find.byType(Center), findsOneWidget);
        final center = tester.widget<Center>(find.byType(Center));
        expect(center.child, isA<SizedBox>());
      });

      testWidgets('respects widthFactor', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            widthFactor: 0.5,
            child: Text('Test'),
          ),
        ));

        final center = tester.widget<Center>(find.byType(Center));
        expect(center.widthFactor, 0.5);
      });

      testWidgets('respects heightFactor', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            heightFactor: 0.5,
            child: Text('Test'),
          ),
        ));

        final center = tester.widget<Center>(find.byType(Center));
        expect(center.heightFactor, 0.5);
      });
    });

    group('video timing', () {
      testWidgets('visible when no timing specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            child: Text('Visible'),
          ),
          frame: 50,
        ));

        expect(find.text('Visible'), findsOneWidget);
      });

      testWidgets('visible when frame is within range', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
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
          const VCenter(
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
          const VCenter(
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
          const VCenter(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            child: Text('Fading'),
          ),
          frame: 10, // Halfway through fade in
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('applies fade out during transition', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            startFrame: 0,
            endFrame: 100,
            fadeOutFrames: 20,
            child: Text('Fading'),
          ),
          frame: 90, // During fade out
        ));

        expect(find.text('Fading'), findsOneWidget);
      });

      testWidgets('uses custom fade curves', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            startFrame: 0,
            endFrame: 100,
            fadeInFrames: 20,
            fadeInCurve: Curves.easeIn,
            fadeOutCurve: Curves.easeOut,
            child: Text('Test'),
          ),
        ));

        final vCenter = tester.widget<VCenter>(find.byType(VCenter));
        expect(vCenter.fadeInCurve, Curves.easeIn);
        expect(vCenter.fadeOutCurve, Curves.easeOut);
      });
    });

    group('default values', () {
      testWidgets('default fade frames are 0', (tester) async {
        const vCenter = VCenter(child: SizedBox());

        expect(vCenter.fadeInFrames, 0);
        expect(vCenter.fadeOutFrames, 0);
      });

      testWidgets('default curves are easeOut/easeIn', (tester) async {
        const vCenter = VCenter(child: SizedBox());

        expect(vCenter.fadeInCurve, Curves.easeOut);
        expect(vCenter.fadeOutCurve, Curves.easeIn);
      });

      testWidgets('default timing is null', (tester) async {
        const vCenter = VCenter(child: SizedBox());

        expect(vCenter.startFrame, isNull);
        expect(vCenter.endFrame, isNull);
      });
    });

    group('edge cases', () {
      testWidgets('handles zero duration (startFrame == endFrame)', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
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
          const VCenter(
            startFrame: 30,
            child: Text('Start Only'),
          ),
          frame: 50,
        ));

        expect(find.text('Start Only'), findsOneWidget);
      });

      testWidgets('handles only endFrame specified', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            endFrame: 100,
            child: Text('End Only'),
          ),
          frame: 50,
        ));

        expect(find.text('End Only'), findsOneWidget);
      });

      testWidgets('handles large frame numbers', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const VCenter(
            startFrame: 100000,
            endFrame: 200000,
            child: Text('Large Frames'),
          ),
          frame: 150000,
          durationInFrames: 300000,
        ));

        expect(find.text('Large Frames'), findsOneWidget);
      });
    });
  });
}
