import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

Map<String, Object?> _deck({bool lanes = true, bool storeAudio = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  if (lanes)
    'audio': [
      {
        'kind': 'music',
        'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      },
      {
        'kind': 'sfx',
        'source': {'kind': 'asset', 'value': 'audio/whoosh.wav'},
        'at': {'kind': 'at', 'time': '20f'},
      },
    ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        if (lanes)
          {
            'id': 'el-clip',
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
            'show': {'from': '10f', 'to': '50f'},
          },
      ],
    },
  ],
  if (storeAudio)
    'editor': {
      'editorSchema': 1,
      'media': [
        {
          'id': 'media-1',
          'name': 'song.mp3',
          'kind': 'audio',
          'source': {'kind': 'asset', 'value': 'audio/song.mp3'},
        },
        {
          'id': 'media-2',
          'name': 'photo.png',
          'kind': 'image',
          'source': {'kind': 'asset', 'value': 'images/photo.png'},
        },
      ],
    },
};

/// A two-scene deck whose scene 1 carries an overlapping `slide` enter, so
/// its settled frame sits past its span start. A music bed gives the panel a
/// lane, so the scene-block row renders and is tappable.
Map<String, Object?> _transitionDeck() => {
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
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '60f',
      'enter': {'kind': 'slide', 'duration': '15f'},
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
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

Future<_Harness> _pump(
  WidgetTester tester, {
  bool lanes = true,
  bool storeAudio = true,
  Map<String, Object?>? deck,
  int length = 210,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(
    EditorDocument.fromJson(deck ?? _deck(lanes: lanes, storeAudio: storeAudio)),
  );
  final transport = SlideTransport(fps: 30, length: length);
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

/// The lanes origin: the timeline's top-left plus the labels column (140)
/// and the ruler strip (24). The panel zooms whole videos at 2 px/frame.
Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

Offset _row(WidgetTester tester, int row, double x) =>
    _lanesOrigin(tester) + Offset(x, row * 28 + 14);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('the panel shows scene blocks and every lane', (tester) async {
    await _pump(tester);
    expect(find.text('Video'), findsOneWidget);
    expect(find.byType(TrackTimeline), findsOneWidget);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('Clip'), findsOneWidget);
    expect(find.text('bed.mp3'), findsOneWidget);
    expect(find.text('whoosh.wav'), findsOneWidget);
  });

  testWidgets('an empty video explains itself', (tester) async {
    await _pump(tester, lanes: false, storeAudio: false);
    expect(
      find.text('Nothing placed in time yet. Import media to lay out clips and audio.'),
      findsOneWidget,
    );
  });

  testWidgets('scrubbing the ruler seeks the shared transport', (tester) async {
    final harness = await _pump(tester);
    final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);
    await _drag(tester, ruler + const Offset(80, 0), const Offset(40, 0));
    expect(harness.transport.frame, 60);
    expect(harness.transport.isPlaying, isFalse);
  });

  testWidgets('dragging a clip lane moves its show window in one merged step', (tester) async {
    final harness = await _pump(tester);
    // el-clip: absolute 130..170 → px 260..340 on lane row 1.
    await _drag(tester, _row(tester, 1, 300), const Offset(40, 0));
    expect(harness.history.document.elementJson('el-clip')!['show'], {
      'from': '30f',
      'to': '70f',
    });
    harness.history.undo();
    expect(harness.history.document.elementJson('el-clip')!['show'], {
      'from': '10f',
      'to': '50f',
    });
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging a clip edge trims its window', (tester) async {
    final harness = await _pump(tester);
    await _drag(tester, _row(tester, 1, 339), const Offset(-20, 0));
    expect(harness.history.document.elementJson('el-clip')!['show'], {
      'from': '10f',
      'to': '40f',
    });
  });

  testWidgets('a music bed body drag places its source in time', (tester) async {
    final harness = await _pump(tester);
    // The music bed on lane row 2 is placed at frame 20.
    await _drag(tester, _row(tester, 2, 100), const Offset(40, 0));
    expect(harness.history.document.audioTracksJson().first['at'], {'kind': 'at', 'time': '20f'});
    expect(harness.history.canUndo, isTrue);
  });

  testWidgets('trimming the music bed writes its trim', (tester) async {
    final harness = await _pump(tester);
    // The bed spans 0..210 → px 0..420; grab the right edge.
    await _drag(tester, _row(tester, 2, 418), const Offset(-20, 0));
    expect(harness.history.document.audioTracksJson()[0]['trim'], {
      'from': '0f',
      'to': '200f',
    });
  });

  testWidgets('dragging a time-placed sfx rewrites its at time', (tester) async {
    final harness = await _pump(tester);
    // The sfx spans 20..50 → px 40..100 on lane row 3.
    await _drag(tester, _row(tester, 3, 70), const Offset(40, 0));
    expect(harness.history.document.audioTracksJson()[1]['at'], {
      'kind': 'at',
      'time': '40f',
    });
  });

  testWidgets('tapping lanes routes the selection: elements, audio, scenes', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_row(tester, 1, 300));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-clip'});
    expect(harness.container.read(audioSelectionProvider), isNull);

    await tester.tapAt(_row(tester, 2, 100));
    await tester.pump();
    expect(
      harness.container.read(audioSelectionProvider),
      const SelectedAudioTrack(scene: null, index: 0),
    );
    expect(harness.container.read(selectionProvider), isEmpty);

    // A scene block tap seeks its start.
    harness.transport.seek(5);
    await tester.tapAt(_row(tester, 0, 300));
    await tester.pump();
    expect(harness.transport.frame, 120);
  });

  testWidgets('a scene-block tap seeks the settled frame, past its transition', (tester) async {
    // Scene 1 spans absolute 45..105 (its slide enter overlaps scene 0), so
    // its settled frame is 60 — the old seek parked at the span start, 45,
    // mid-transition, where the canvas geometry no longer matches the render.
    final harness = await _pump(tester, deck: _transitionDeck(), length: 105);
    harness.transport.seek(5);
    // Scene 1's block spans px 90..210 on the scenes row; tap inside it.
    await tester.tapAt(_row(tester, 0, 150));
    await tester.pump();
    expect(harness.transport.frame, 60);
  });

  testWidgets('tapping empty lane space scrubs there', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_row(tester, 1, 100));
    await tester.pump();
    expect(harness.transport.frame, 50);
  });

  testWidgets('the add-audio picker lists the store audio and appends a track', (tester) async {
    final harness = await _pump(tester);
    final select = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('video-add-audio')));
    expect(select.options.map((option) => option.value), ['media-1']);
    select.onChanged!('media-1');
    await tester.pump();
    expect(harness.history.document.audioTracksJson().last, {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/song.mp3'},
    });
    expect(find.text('song.mp3'), findsWidgets);
    harness.history.undo();
    expect(harness.history.document.audioTracksJson(), hasLength(2));
  });

  testWidgets('a deck with no imported audio hides the picker', (tester) async {
    await _pump(tester, storeAudio: false);
    expect(find.byKey(const ValueKey('video-add-audio')), findsNothing);
  });

  testWidgets('play and pause run on the shared transport, and collapse folds', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    expect(harness.transport.isPlaying, isTrue);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(harness.transport.isPlaying, isFalse);

    await tester.tap(find.bySemanticsLabel('Collapse the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsOneWidget);
  });
}
