import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

import 'fixtures/track_timeline_fixture.dart';

void main() {
  for (final scenario in ['selection', 'playhead', 'length', 'range', 'snap', 'overlays']) {
    testWidgets('retained public lane builder paints current $scenario values', (tester) async {
      final f = TimelineFixture();
      if (scenario == 'selection') f.links = fixtureLinks;
      try {
        await f.mount(tester);
        final oldTarget = tester.widget<DragTarget<Object>>(laneTarget());
        final retained = oldTarget.builder;
        final lanePaintFinder = find.descendant(
          of: laneTarget(),
          matching: find.byType(CustomPaint),
        );
        final size = tester.getSize(lanePaintFinder);
        final before = await paintBytes(
          tester,
          paintFromPublicBuilder(
            retained(tester.element(laneTarget()), const [], const []),
          ).painter!,
          size,
        );
        switch (scenario) {
          case 'selection':
            f
              ..selectedTrackIds = {'first'}
              ..selectedBarIds = {'bar-a'}
              ..selectedDiamondId = 'diamond-a'
              ..selectedLinkId = 'link-a';
          case 'playhead':
            f.playhead = 35;
          case 'length':
            f.totalFrames = 150;
          case 'range':
            f.range = (start: 10, end: 40);
          case 'snap':
            f.snapFrame = 32;
          case 'overlays':
            f
              ..links = fixtureLinks
              ..markers = const [TimelineMarker(id: 'cue', frame: 45, label: 'Cue')];
        }
        await f.update(tester);
        final context = tester.element(laneTarget());
        final current = tester.widget<DragTarget<Object>>(laneTarget()).builder;
        final retainedBytes = await paintBytes(
          tester,
          paintFromPublicBuilder(retained(context, const [], const [])).painter!,
          size,
        );
        final currentBytes = await paintBytes(
          tester,
          paintFromPublicBuilder(current(context, const [], const [])).painter!,
          size,
        );
        expect(currentBytes, isNot(orderedEquals(before)), reason: 'visible $scenario sensitivity');
        expect(
          retainedBytes,
          orderedEquals(currentBytes),
          reason: 'invocation-time current widget',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose(tester);
      }
    });
  }

  testWidgets('retained public drop callbacks read replacement widget both directions', (
    tester,
  ) async {
    final f = TimelineFixture();
    try {
      await f.mount(tester);
      final retained = tester.widget<DragTarget<Object>>(laneTarget());
      final lane = tester.getRect(laneTarget());
      final details = DragTargetDetails<Object>(
        data: 'payload',
        offset: lane.topLeft + const Offset(100, 14),
      );
      expect(retained.onWillAcceptWithDetails!(details), isFalse);
      f
        ..generation = 'B'
        ..acceptsDrop = true;
      await f.update(tester);
      expect(retained.onWillAcceptWithDetails!(details), isTrue);
      retained.onAcceptWithDetails!(details);
      expect(f.events, ['B:drop:payload:first:bar-a:25.0']);
      f
        ..generation = 'C'
        ..acceptsDrop = false;
      await f.update(tester);
      expect(retained.onWillAcceptWithDetails!(details), isFalse);
      retained.onAcceptWithDetails!(details);
      expect(f.events, ['B:drop:payload:first:bar-a:25.0']);
    } finally {
      await f.dispose(tester);
    }
  });

  testWidgets('retained focus key and drag callbacks use latest host intentions', (tester) async {
    final f = TimelineFixture();
    try {
      await f.mount(tester);
      final target = tester.widget<DragTarget<Object>>(laneTarget());
      final original = target.builder(tester.element(laneTarget()), const [], const []) as Focus;
      final oldKey = original.onKeyEvent!;
      final focus = original.focusNode!;
      final drag = tester.widget<GestureDetector>(
        find.descendant(of: laneTarget(), matching: find.byType(GestureDetector)),
      );
      focus.requestFocus();
      await tester.pump();
      f
        ..generation = 'B'
        ..selectedDiamondId = 'diamond-a'
        ..range = (start: 10, end: 40);
      await f.update(tester);
      final current = tester.widget<Focus>(
        find.descendant(of: laneTarget(), matching: find.byType(Focus)).first,
      );
      expect(current.focusNode, same(focus));
      expect(focus.hasFocus, isTrue);
      expect(
        oldKey(
          focus,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.delete,
            logicalKey: LogicalKeyboardKey.delete,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.handled,
      );
      expect(
        oldKey(
          focus,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.handled,
      );
      drag.onTapUp!(
        TapUpDetails(kind: PointerDeviceKind.mouse, localPosition: const Offset(50, 14)),
      );
      drag.onHorizontalDragStart!(DragStartDetails(localPosition: const Offset(50, 14)));
      drag.onHorizontalDragUpdate!(
        DragUpdateDetails(
          globalPosition: tester.getRect(laneTarget()).topLeft + const Offset(70, 14),
          delta: const Offset(20, 0),
          primaryDelta: 20,
          localPosition: const Offset(70, 14),
        ),
      );
      drag.onHorizontalDragEnd!(DragEndDetails());
      expect(f.events, [
        'B:delete:bar-a:diamond-a',
        'B:clear',
        'B:tap:bar-a:false',
        'B:start:bar-a',
        'B:move:bar-a:5.0:first',
        'B:end:bar-a',
      ]);
      f
        ..generation = 'C'
        ..selectedDiamondId = null
        ..range = null;
      await f.update(tester);
      expect(
        oldKey(
          focus,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.ignored,
      );
      expect(f.events, hasLength(6));
      expect(tester.takeException(), isNull);
    } finally {
      await f.dispose(tester);
    }
  });

  testWidgets('selection rebuild retains controller and replacement detaches exact listener', (
    tester,
  ) async {
    final f = TimelineFixture();
    // The final controller's exact listener-detach lifecycle is deliberately observed.
    // ignore: invalid_use_of_protected_member
    expect(f.firstController.hasListeners, isFalse);
    // The final controller's exact listener-detach lifecycle is deliberately observed.
    // ignore: invalid_use_of_protected_member
    expect(f.secondController.hasListeners, isFalse);
    try {
      await f.mount(tester);
      // The final controller's exact listener-detach lifecycle is deliberately observed.
      // ignore: invalid_use_of_protected_member
      expect(f.firstController.hasListeners, isTrue);
      f.firstController.zoomIn();
      await tester.pumpAndSettle();
      f.selectedTrackIds = {'first'};
      await f.update(tester);
      expect(
        tester.widget<TrackTimeline>(find.byKey(timelineKey)).controller,
        same(f.firstController),
      );
      expect(f.firstController.pixelsPerFrame, 5);
      f.replacementController = f.secondController;
      await f.update(tester);
      // The final controller's exact listener-detach lifecycle is deliberately observed.
      // ignore: invalid_use_of_protected_member
      expect(f.firstController.hasListeners, isFalse);
      // The final controller's exact listener-detach lifecycle is deliberately observed.
      // ignore: invalid_use_of_protected_member
      expect(f.secondController.hasListeners, isTrue);
      expect(
        tester.widget<TrackTimeline>(find.byKey(timelineKey)).controller,
        same(f.secondController),
      );
      f.firstController.zoomOut();
      await tester.pump();
      expect(f.secondController.pixelsPerFrame, 6);
      expect(tester.takeException(), isNull);
    } finally {
      await f.dispose(tester);
    }
  });
}
