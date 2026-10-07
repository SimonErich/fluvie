import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('Quick projects two editable lanes and preserves the full document', (tester) async {
    final doc = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'lanes': [
        {'id': 'main', 'kind': 'video', 'name': 'Main'},
        {'id': 'voice', 'kind': 'audio', 'name': 'Voice'},
        {'id': 'empty', 'kind': 'video'},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'music.wav'},
          'lane': 'voice',
          'at': {'kind': 'at', 'time': '15f'},
          'trim': {'from': '0f', 'to': '30f'},
        },
      ],
      'scenes': [
        {
          'duration': '120f',
          'children': [
            {
              'type': 'Text',
              'id': 'title',
              'text': 'Hi',
              'lane': 'main',
              'show': {'from': '0f', 'to': '60f'},
            },
          ],
        },
      ],
    });
    final history = DocumentHistory(doc);
    addTearDown(history.dispose);
    final transport = SlideTransport(fps: 30, length: 120);
    addTearDown(transport.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final workspace = ValueNotifier(EditorWorkspace.quick);
    final placed = <(String, int)>[];
    var placementEnabled = true;
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          home: ValueListenableBuilder(
            valueListenable: workspace,
            builder: (context, mode, _) => WorkspaceScope(
              workspace: mode,
              child: ListenableBuilder(
                listenable: history,
                builder: (context, _) => Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 750,
                    child: VideoModePanel(
                      document: history.document,
                      transport: transport,
                      onCommand: history.dispatch,
                      onSourceDropped: placementEnabled
                          ? (source, row, frame) => placed.add((row, frame))
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    TrackTimeline timeline() => tester.widget<TrackTimeline>(find.byType(TrackTimeline));
    expect(timeline().tracks.map((row) => row.label), ['Picture', 'Audio']);
    expect(timeline().tracks.every((row) => !row.showLaneControls), isTrue);
    expect(timeline().tracks.last.bars.single.start, 15);
    const picture = (
      entry: MediaStoreEntry(
        id: 'video',
        name: 'video',
        kind: MediaStoreKind.video,
        source: {'kind': 'asset', 'value': 'video.mp4'},
      ),
      start: 0,
      end: 30,
    );
    const audio = (
      entry: MediaStoreEntry(
        id: 'audio',
        name: 'audio',
        kind: MediaStoreKind.audio,
        source: {'kind': 'asset', 'value': 'audio.wav'},
      ),
      start: 0,
      end: 30,
    );
    timeline().edit.onForeignLaneDrop!(picture, 'quick:audio', null, 20);
    await tester.pump();
    expect(find.textContaining('Audio belongs on the Audio lane'), findsOneWidget);
    expect(placed, isEmpty);
    timeline().edit.onForeignLaneDrop!(picture, 'quick:pictures', null, 20);
    await tester.pump();
    expect(placed.last, ('lane:main', 20));
    container.read(activeTimelineLaneProvider.notifier).select('empty');
    timeline().edit.onForeignLaneDrop!(picture, 'quick:pictures', null, 25);
    await tester.pump();
    expect(placed.last, ('lane:empty', 25));
    timeline().edit.onForeignLaneDrop!(audio, 'quick:audio', null, 30);
    await tester.pump();
    expect(placed.last, ('lane:voice', 30));
    timeline().navigation.onBarTapped!('el:title', additive: false);
    await tester.pump();
    expect(container.read(selectionProvider), {'title'});
    expect(timeline().selection.selectedTrackIds, {'quick:pictures'});
    timeline().edit.onBarMoved!('el:title', 10, 'quick:pictures');
    await tester.pump();
    expect(history.document.elementJson('title')!['show'], {'from': '10f', 'to': '70f'});
    expect(history.document.elementJson('title')!['lane'], 'main');
    final authored = history.document.toJson();
    workspace.value = EditorWorkspace.edit;
    await tester.pump();
    expect(timeline().tracks.where((row) => row.showLaneControls).map((row) => row.label), [
      'V1 · Main',
      'A1 · Voice',
      'V2 · empty',
    ]);
    expect(history.document.toJson(), authored);
    timeline().edit.onForeignLaneDrop!(picture, 'lane:voice', null, 40);
    await tester.pump();
    expect(find.textContaining('Audio belongs on an audio lane'), findsOneWidget);
    history.dispatch(const SetLaneCommand(id: 'empty', patch: {'locked': true}));
    await tester.pump();
    timeline().edit.onForeignLaneDrop!(picture, 'lane:empty', null, 40);
    await tester.pump();
    expect(find.textContaining('Unlock the lane'), findsOneWidget);
    workspace.value = EditorWorkspace.quick;
    await tester.pump();
    timeline().edit.onBarMoved!('audio:v:0', 25, 'quick:audio');
    await tester.pump();
    expect(timeline().tracks.last.bars.single.start, 25);
    expect(history.document.audioTracksJson().single['lane'], 'voice');
    placementEnabled = false;
    workspace.value = EditorWorkspace.edit;
    await tester.pump();
    timeline().edit.onForeignLaneDrop!(picture, 'lane:main', null, 40);
    await tester.pump();
    expect(find.textContaining('does not support source placement'), findsOneWidget);
  });
}
