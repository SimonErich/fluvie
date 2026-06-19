// Inspector panel widget tests (WI-19/20/21): the structured panel binds to
// the InspectorViewModel's model — it lists the motion rows and anchors, shows
// a warnings band, and tapping a row or anchor seeks the playback controller
// to that frame (jump to trigger). The timeline is pushed straight into the
// probe, so no Video mounts and no real resolution runs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/inspector_panel.dart';
import 'package:fluvie_example/inspector/playback_view_model.dart';
import 'package:fluvie_example/inspector/providers.dart';

const _timeline = ResolvedTimeline(
  fps: 30,
  totalFrames: 120,
  rows: [
    TimelineRow(
      ownerId: 's0e0:Text',
      label: 'pop',
      phase: AnimationPhase.enter,
      startFrame: 0,
      endFrame: 18,
    ),
    TimelineRow(
      ownerId: 's0e1:Text',
      label: 'fade',
      phase: AnimationPhase.exit,
      startFrame: 60,
      endFrame: 90,
    ),
  ],
  anchors: [TimelineAnchor(name: 'intro', frame: 42)],
  warnings: ['s0e0:Text pop overhangs the window'],
);

void main() {
  late ProviderContainer container;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const scope = ProviderScope(
      child: MaterialApp(home: Scaffold(body: InspectorPanel())),
    );
    await tester.pumpWidget(scope);
    container = ProviderScope.containerOf(
      tester.element(find.byType(InspectorPanel)),
    );
  }

  void pushTimeline(ResolvedTimeline timeline) {
    container.read(timelineProbeProvider).value = timeline;
  }

  testWidgets('shows a pending hint before the first resolution', (tester) async {
    await pumpPanel(tester);

    expect(find.textContaining('pending'), findsOneWidget);
  });

  testWidgets('shows a timing error when the probe reports one', (tester) async {
    await pumpPanel(tester);
    container.read(timelineProbeProvider).reportError('no beat grid for track music');
    await tester.pump();

    expect(find.textContaining('Timing error'), findsOneWidget);
    expect(find.textContaining('no beat grid for track music'), findsOneWidget);
    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('lists every motion row with its owner, label and span', (tester) async {
    await pumpPanel(tester);
    pushTimeline(_timeline);
    await tester.pump();

    expect(find.text('s0e0:Text'), findsOneWidget);
    expect(find.text('pop (enter)'), findsOneWidget);
    expect(find.text('0..18'), findsOneWidget);
    expect(find.text('s0e1:Text'), findsOneWidget);
    expect(find.text('fade (exit)'), findsOneWidget);
    expect(find.text('60..90'), findsOneWidget);
  });

  testWidgets('lists every anchor with its resolved frame (WI-20)', (tester) async {
    await pumpPanel(tester);
    pushTimeline(_timeline);
    await tester.pump();

    expect(find.textContaining('intro'), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('shows the warnings band when the model has warnings (WI-21)', (tester) async {
    await pumpPanel(tester);
    pushTimeline(_timeline);
    await tester.pump();

    expect(find.textContaining('overhangs'), findsOneWidget);
  });

  testWidgets('hides the warnings band when there are none (WI-21)', (tester) async {
    await pumpPanel(tester);
    pushTimeline(
      const ResolvedTimeline(fps: 30, totalFrames: 60, rows: []),
    );
    await tester.pump();

    expect(find.textContaining('overhangs'), findsNothing);
  });

  testWidgets('tapping a motion row seeks the preview to its jump frame (WI-20)', (tester) async {
    await pumpPanel(tester);
    pushTimeline(_timeline);
    await tester.pump();

    await tester.tap(find.text('s0e1:Text'));
    await tester.pump();

    expect(container.read(playbackViewModelProvider).frame, 60);
    expect(container.read(playbackViewModelProvider.notifier).controller.frame, 60);
  });

  testWidgets('tapping an anchor seeks the preview to its frame (WI-20)', (tester) async {
    await pumpPanel(tester);
    pushTimeline(_timeline);
    await tester.pump();

    await tester.tap(find.textContaining('intro'));
    await tester.pump();

    expect(container.read(playbackViewModelProvider).frame, 42);
  });
}
