import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

Map<String, Object?> _deck({bool locked = false}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': [
    {'id': 'v1', 'name': 'Video 1', 'locked': locked},
    {'id': 'v2', 'name': 'Video 2'},
    {'id': 'a1', 'name': 'Audio', 'kind': 'audio'},
  ],
  'audio': [
    {
      'id': 'bed',
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'a.wav'},
      'lane': 'a1',
    },
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'a.mp4'},
          'lane': 'v1',
          'show': {'from': '0f', 'to': '30f'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'b.mp4'},
          'lane': 'v2',
          'show': {'from': '30f', 'to': '60f'},
        },
      ],
    },
  ],
};

void main() {
  test('locked lane refuses move, trim, razor, ripple, slip and slide', () {
    final doc = EditorDocument.fromJson(_deck(locked: true));
    final model = VideoLaneModel.build(document: doc);
    final edits = [
      videoBarMoved(model, 'el:a', 10),
      videoBarResized(model, 'el:a', 0, 20),
      videoBarRazored(model, 'el:a', 10, document: doc),
      videoRippleDeleted(model, {'el:a'}, document: doc),
      videoSlipped(model, 'el:a', 2, document: doc),
      videoSlid(model, 'el:a', 2, document: doc),
      videoBarRelaned(model, 'el:b', 'lane:v1', document: doc),
    ];
    for (final edit in edits) {
      expect(edit?.command, isNull);
      expect(edit?.note, contains('nlock'));
    }
  });
  testWidgets('a real source drag targets an empty declared lane and global frame', (tester) async {
    final doc = EditorDocument.fromJson(_deck());
    final transport = SlideTransport(fps: 30, length: 120);
    const source = (
      entry: MediaStoreEntry(
        id: 'file',
        name: 'clip',
        kind: MediaStoreKind.video,
        source: {'kind': 'asset', 'value': 'clip.mp4'},
      ),
      start: 5,
      end: 25,
    );
    String? row;
    int? frame;
    await tester.pumpWidget(
      ProviderScope(
        child: OiApp(
          home: Column(
            children: [
              const Draggable<SourceMonitorPlacement>(
                data: source,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: SizedBox.square(dimension: 4),
                child: SizedBox(
                  key: Key('source-chip'),
                  width: 40,
                  height: 40,
                  child: ColoredBox(color: Color(0xff555555)),
                ),
              ),
              VideoModePanel(
                document: doc,
                transport: transport,
                onCommand: (_) {},
                onSourceDropped: (payload, target, at) {
                  expect(payload, source);
                  row = target;
                  frame = at;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final target =
        tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140 + 180, 24 + 2 * 28 + 14);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('source-chip'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(2, 2));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(row, 'lane:v2');
    expect(frame, 90);
    await tester.pumpWidget(const SizedBox());
    transport.dispose();
  });
  testWidgets('lane chrome, relaning and undo go through the production panel', (tester) async {
    final doc = EditorDocument.fromJson(_deck());
    final history = DocumentHistory(doc);
    final transport = SlideTransport(fps: 30, length: 120);
    final monitor = AudioMonitorController();
    await tester.pumpWidget(
      ProviderScope(
        child: OiApp(
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => VideoModePanel(
              document: history.document,
              transport: transport,
              onCommand: history.dispatch,
              audioMonitor: monitor,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    TrackTimeline timeline() => tester.widget<TrackTimeline>(find.byType(TrackTimeline));
    timeline().lanes.onLaneLockToggled!('lane:v1');
    await tester.pump();
    expect(history.document.spec.lanes.first.locked, isTrue);
    history.undo();
    await tester.pump();
    timeline().lanes.onLaneMuteToggled!('lane:a1');
    await tester.pump();
    expect(history.document.spec.build().audio, isEmpty);
    history.undo();
    await tester.pump();
    final digest = history.document.renderDigest;
    timeline().lanes.onLaneSoloToggled!('lane:a1');
    await tester.pump();
    expect(monitor.isSoloed('a1'), isTrue);
    expect(history.document.renderDigest, digest);
    expect(timeline().tracks.singleWhere((row) => row.id == 'lane:a1').soloed, isTrue);
    timeline().lanes.onLaneReordered!('lane:v1', 2);
    await tester.pump();
    expect(history.document.spec.lanes.take(2).map((lane) => lane.id), ['v2', 'v1']);
    expect(history.document.elementIdsInScene(0), ['a', 'b']);
    history.undo();
    await tester.pump();
    timeline().edit.onDragStarted!('el:a');
    timeline().edit.onBarMoved!('el:a', 10, 'lane:v2');
    timeline().edit.onDragEnded!('el:a');
    await tester.pump();
    expect(history.document.elementJson('a')!['show'], {'from': '10f', 'to': '40f'});
    expect(history.document.elementJson('a')!['lane'], 'v2');
    history.undo();
    await tester.pump();
    expect(history.document.toJson(), doc.toJson());
    timeline().edit.onDragStarted!('audio:v:0');
    timeline().edit.onBarMoved!('audio:v:0', 0, 'lane:v2');
    timeline().edit.onDragEnded!('audio:v:0');
    await tester.pump();
    expect(history.document.audioTracksJson().single['lane'], 'v2');
    expect(history.document.audioTracksJson().single['id'], 'bed');
    await tester.pumpWidget(const SizedBox());
    history.dispose();
    transport.dispose();
    monitor.dispose();
  });
}
