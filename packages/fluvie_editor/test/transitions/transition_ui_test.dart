import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'transition_edits_test.dart' show deck;

void main() {
  testWidgets('transition drag and removal preserve the cut, and rate stretch changes speed', (
    tester,
  ) async {
    final history = DocumentHistory(deck());
    final transport = SlideTransport(fps: 30, length: 180);
    await tester.pumpWidget(
      ProviderScope(
        child: OiApp(
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => VideoModePanel(
              document: history.document,
              transport: transport,
              onCommand: history.dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Transitions').first);
    await tester.pumpAndSettle();
    final timelineRect = tester.getRect(find.byType(TrackTimeline));
    final source = tester.getCenter(find.text('Dissolve'));
    final gesture = await tester.startGesture(source);
    await gesture.moveTo(source + const Offset(30, 30));
    await tester.pump();
    await gesture.moveTo(Offset(timelineRect.left + 140 + 120, timelineRect.top + 24 + 28 + 14));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(history.document.spec.scenes.single.transitions, hasLength(1));
    final timeline = tester.widget<TrackTimeline>(find.byType(TrackTimeline));
    final bar = timeline.tracks
        .expand((row) => row.bars)
        .singleWhere((bar) => bar.id.startsWith('transition:'));
    timeline.edit.onDragStarted!.call(bar.id);
    timeline.edit.onBarResized!.call(bar.id, 50, 60);
    timeline.edit.onDragEnded!.call(bar.id);
    await tester.pumpAndSettle();
    expect(
      VideoLaneModel.build(document: history.document).transitionBars.values.single.window.start,
      50,
    );
    tester.widget<TrackTimeline>(find.byType(TrackTimeline)).navigation.onBarTapped!(
      bar.id,
      additive: false,
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Remove transition').first);
    await tester.pump();
    expect(history.document.spec.scenes.single.transitions, isEmpty);
    await tester.tap(find.text('Rate stretch'));
    await tester.pump();
    tester.widget<TrackTimeline>(find.byType(TrackTimeline)).edit.onDragStarted!('el:a');
    tester.widget<TrackTimeline>(find.byType(TrackTimeline)).edit.onBarResized!('el:a', 0, 30);
    tester.widget<TrackTimeline>(find.byType(TrackTimeline)).edit.onDragEnded!('el:a');
    await tester.pump();
    expect(history.document.elementJson('a')!['speed'], 2);
    expect(history.document.elementJson('a')!['show'], {'from': '0f', 'to': '30f'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    history.dispose();
    transport.dispose();
  });
  testWidgets('clicking the easing sketch requests Animation after selecting its element', (
    tester,
  ) async {
    String? selected;
    String? easing;
    await tester.pumpWidget(
      OiApp(
        home: Center(
          child: SizedBox(
            width: 620,
            height: 220,
            child: TrackTimeline(
              fps: 30,
              totalFrames: 100,
              tracks: const [
                TimelineTrack(
                  id: 'row',
                  label: 'Curve',
                  bars: [
                    TimelineBar(
                      id: 'bar',
                      start: 0,
                      end: 50,
                      color: Color(0xff4488ff),
                      easing: Curves.linear,
                    ),
                  ],
                ),
              ],
              navigation: TrackTimelineNavigation(
                onBarTapped: (id, {required additive}) => selected = id,
              ),
              edit: TrackTimelineEditActions(
                onEasingTapped: (id) => easing = id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(TrackTimeline));
    await tester.tapAt(Offset(rect.left + 140 + 100, rect.top + 24 + 14));
    await tester.pump();
    expect(selected, 'bar');
    expect(easing, 'bar');
  });
  testWidgets('explicit animation request reveals tab and manual selection remains respected', (
    tester,
  ) async {
    InspectorTabRequest? request;
    late StateSetter refresh;
    await tester.pumpWidget(
      OiApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return InspectorTabs(
              request: request,
              inspector: const Text('Inspector body'),
              panels: const {InspectorTab.animation: Text('Curves body')},
            );
          },
        ),
      ),
    );
    refresh(() => request = InspectorTabRequest(InspectorTab.animation));
    await tester.pumpAndSettle();
    expect(find.text('Curves body'), findsOneWidget);
    await tester.tap(find.text('Inspector'));
    await tester.pumpAndSettle();
    expect(find.text('Inspector body'), findsOneWidget);
    refresh(() => request = InspectorTabRequest(InspectorTab.animation));
    await tester.pumpAndSettle();
    expect(find.text('Curves body'), findsOneWidget);
  });
}
