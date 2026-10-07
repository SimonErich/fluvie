import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// A video with a music bed and a windowed clip lane, so both an element and
/// an audio track can be selected and highlighted.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'audio/theme.mp3'},
        },
      ],
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'show': {'from': '10f', 'to': '50f'},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history, this.transport);
  final ProviderContainer container;
  final DocumentHistory history;
  final SlideTransport transport;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final transport = SlideTransport(fps: 30, length: 120);
  addTearDown(transport.dispose);
  final harness = _Harness(container, history, transport);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 640,
              child: VideoModePanel(
                document: history.document,
                transport: transport,
                onCommand: history.dispatch,
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

/// The lanes origin: the timeline's top-left plus the labels column (140)
/// and the ruler strip (24). The panel zooms whole videos at 2 px/frame.
Offset _row(WidgetTester tester, int row, double x) =>
    tester.getTopLeft(find.byType(TrackTimeline)) +
    const Offset(140, 24) +
    Offset(x, row * 28 + 14);

Future<void> _band(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveTo(Offset(from.dx + 4, from.dy));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('selecting an element highlights its lane', (tester) async {
    final harness = await _pump(tester);
    expect(_timeline(tester).selection.selectedTrackIds, isEmpty);
    harness.container.read(selectionProvider.notifier).select({'el-clip'});
    await tester.pump();
    expect(_timeline(tester).selection.selectedTrackIds, contains('el-track:el-clip'));
  });

  testWidgets('selecting an audio track highlights its lane', (tester) async {
    final harness = await _pump(tester);
    harness.container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: null, index: 0));
    await tester.pump();
    expect(_timeline(tester).selection.selectedTrackIds, contains('audio-track:v:0'));
  });

  testWidgets('tapping an element label selects the element and clears audio', (tester) async {
    final harness = await _pump(tester);
    harness.container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: null, index: 0));
    await tester.tap(find.text('Clip'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-clip'});
    expect(harness.container.read(audioSelectionProvider), isNull);
  });

  testWidgets('tapping an audio label selects the track and clears elements', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(selectionProvider.notifier).select({'el-clip'});
    await tester.tap(find.text('bed.mp3'));
    await tester.pump();
    expect(
      harness.container.read(audioSelectionProvider),
      const SelectedAudioTrack(scene: null, index: 0),
    );
    expect(harness.container.read(selectionProvider), isEmpty);
  });

  testWidgets('a scene-scoped audio track highlights and selects by scene', (tester) async {
    final harness = await _pump(tester);
    // Highlight from selection: the scene-0 track lane paints.
    harness.container
        .read(audioSelectionProvider.notifier)
        .select(const SelectedAudioTrack(scene: 0, index: 0));
    await tester.pump();
    expect(_timeline(tester).selection.selectedTrackIds, contains('audio-track:s:0:0'));
    // A tap on its label round-trips back to the same scene selection.
    await tester.tap(find.text('theme.mp3 (slide 1)'));
    await tester.pump();
    expect(
      harness.container.read(audioSelectionProvider),
      const SelectedAudioTrack(scene: 0, index: 0),
    );
  });

  testWidgets('tapping a bar selects it on the timeline as well as on the canvas', (tester) async {
    // Two selections, deliberately: the bar is a span of time on a lane and
    // the element is a thing on the canvas, and a verb aimed at one must not
    // find the other.
    final harness = await _pump(tester);

    await tester.tapAt(_row(tester, 1, 60));
    await tester.pump();

    expect(harness.container.read(timelineSelectionProvider), {'el:el-clip'});
    expect(harness.container.read(selectionProvider), {'el-clip'});
    expect(_timeline(tester).selection.selectedBarIds, {'el:el-clip'});
  });

  testWidgets('a rubber band over empty lane space clears the bar selection', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(timelineSelectionProvider.notifier).select({'el:el-clip'});

    // Row 0 is the scenes lane; sweep past the video's end, where nothing is.
    await _band(tester, _row(tester, 0, 300), _row(tester, 0, 400));

    expect(harness.container.read(timelineSelectionProvider), isEmpty);
  });

  testWidgets('a selected bar that leaves the document leaves the selection', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(timelineSelectionProvider.notifier).select({'el:el-clip', 'el:gone'});

    await tester.pump();
    await tester.pump();

    expect(harness.container.read(timelineSelectionProvider), {'el:el-clip'});
  });
}
