import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// A slide with an animated element (so the timeline shows) and a bar-less
/// element (a still Box) — the case only the label tap can select.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {'id': 'el-box', 'type': 'Box', 'width': 80, 'height': 40},
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Title',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-box': {'name': 'Backdrop'},
      'el-title': {'name': 'Heading'},
    },
  },
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final harness = _Harness(container, DocumentHistory(EditorDocument.fromJson(_deck())));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: harness.history,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 640,
              child: TimelinePanel(
                document: harness.history.document,
                slide: 0,
                onCommand: harness.history.dispatch,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

TrackTimeline _timeline(WidgetTester tester) =>
    tester.widget<TrackTimeline>(find.byType(TrackTimeline));

void main() {
  testWidgets('selecting an element highlights its track', (tester) async {
    final harness = await _pump(tester);
    expect(_timeline(tester).selection.selectedTrackIds, isEmpty);
    // A bar-less still element can only be highlighted from the selection.
    harness.container.read(selectionProvider.notifier).select({'el-box'});
    await tester.pump();
    expect(_timeline(tester).selection.selectedTrackIds, {'el-box'});
  });

  testWidgets('a bar-less element is selectable from its label', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Backdrop'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-box'});
  });

  testWidgets('a label tap clears any keyframe sub-selection', (tester) async {
    final harness = await _pump(tester);
    harness.container
        .read(keyframeSelectionProvider.notifier)
        .select(const SelectedKeyframe(elementId: 'el-title', animation: 0, stop: 0));
    await tester.tap(find.text('Heading'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-title'});
    expect(harness.container.read(keyframeSelectionProvider), isNull);
  });
}
