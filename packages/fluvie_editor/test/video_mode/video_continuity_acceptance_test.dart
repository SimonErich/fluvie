import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

Map<String, Object?> deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'overlays': [
    {
      'id': 'logo',
      'type': 'Text',
      'text': 'Logo',
      'show': {'from': '40f', 'to': '120f'},
    },
  ],
  'lanes': [
    {'id': 'v1', 'name': 'Video'},
    {'id': 'v2', 'name': 'Overlay'},
  ],
  'scenes': [
    for (var i = 0; i < 3; i++)
      {
        'duration': '60f',
        'children': [
          {
            'id': 'title$i',
            'type': 'Text',
            'text': 'Title',
            'shared': 'hero',
            'transform': {'x': i / 10, 'y': 0.1, 'width': 0.5, 'height': 0.2},
            'show': {'from': '0f', 'to': '60f'},
          },
        ],
      },
  ],
};

void main() {
  test('declared empty lanes remain visible', () {
    final json = deck()..remove('overlays');
    json['scenes'] = [
      {
        'duration': '60f',
        'children': [
          {'type': 'Text', 'text': 'Hello'},
        ],
      },
    ];
    expect(VideoLaneModel.build(document: EditorDocument.fromJson(json)).hasLanes, isTrue);
  });
  test('shared chain draws one logical bar across three scenes', () {
    final model = VideoLaneModel.build(document: EditorDocument.fromJson(deck()));
    expect(model.elementBars.length, 1);
    final row = model.tracks.singleWhere((row) => row.bars.any((bar) => bar.id == 'el:title0'));
    expect(row.bars.single.start, 0);
    expect(row.bars.single.end, 180);
  });
  test('content command propagates only changed content, preserving geometry', () {
    final doc = EditorDocument.fromJson(deck());
    final history = DocumentHistory(doc)
      ..dispatch(
        ReplaceElementCommand(
          id: 'title0',
          element: {
            ...doc.elementJson('title0')!,
            'text': 'New title',
          },
        ),
      );
    for (var i = 0; i < 3; i++) {
      expect(history.document.elementJson('title$i')!['text'], 'New title');
      expect(
        history.document.elementJson('title$i')!['transform'],
        doc.elementJson('title$i')!['transform'],
      );
    }
    history.undo();
    expect(history.document.toJson(), doc.toJson());
  });
  test('shared timing changes all members but transform edits stay local', () {
    final doc = EditorDocument.fromJson(deck());
    final model = VideoLaneModel.build(document: doc);
    final command = videoBarResized(model, 'el:title0', 5, 175)!.command!;
    final history = DocumentHistory(doc)..dispatch(command);
    for (var i = 0; i < 3; i++) {
      expect(history.document.elementJson('title$i')!['show'], {'from': '5f', 'to': '55f'});
    }
    history.undo();
    expect(history.document.toJson(), doc.toJson());
    final transformed = ReplaceElementCommand(
      id: 'title1',
      element: {
        ...doc.elementJson('title1')!,
        'transform': const {'x': 0.4, 'y': 0.5, 'w': 0.3, 'h': 0.2},
      },
    ).apply(doc);
    expect(
      transformed.elementJson('title0')!['transform'],
      doc.elementJson('title0')!['transform'],
    );
    expect(
      transformed.elementJson('title2')!['transform'],
      doc.elementJson('title2')!['transform'],
    );
    history.dispose();
  });
  test('overlay move and trim use whole-video clock', () {
    final doc = EditorDocument.fromJson(deck());
    final model = VideoLaneModel.build(document: doc);
    final move = videoBarMoved(model, 'overlay:logo', 70);
    expect(move?.command, isNotNull);
    expect(move!.command!.apply(doc).elementJson('logo')!['show'], {'from': '70f', 'to': '150f'});
    final trim = videoBarResized(model, 'overlay:logo', 30, 160);
    expect(trim?.command, isNotNull);
    expect(trim!.command!.apply(doc).elementJson('logo')!['show'], {'from': '30f', 'to': '160f'});
  });
  testWidgets('overlay selection survives rebuild and highlights its actual lane', (tester) async {
    final container = ProviderContainer();
    final history = DocumentHistory(EditorDocument.fromJson(deck()));
    final transport = SlideTransport(fps: 30, length: 180);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    TrackTimeline timeline() => tester.widget<TrackTimeline>(find.byType(TrackTimeline));
    timeline().navigation.onBarTapped!('overlay:logo', additive: false);
    await tester.pump();
    await tester.pump();
    expect(container.read(selectionProvider), {'logo'});
    expect(container.read(timelineSelectionProvider), {'overlay:logo'});
    expect(timeline().selection.selectedTrackIds, contains('overlay-track:logo'));
    history.dispatch(const RemoveElementCommand(id: 'logo'));
    await tester.pump();
    await tester.pump();
    expect(container.read(timelineSelectionProvider), isEmpty);
    history.undo();
    await tester.pump();
    expect(timeline().tracks.expand((t) => t.bars).any((b) => b.id == 'overlay:logo'), isTrue);
    await tester.pumpWidget(const SizedBox());
    transport.dispose();
    container.dispose();
    history.dispose();
  });
}
