// The razor as a registry verb: it cuts the selected bars at the playhead,
// and reads as disabled wherever a cut would have nothing to land on.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// One 120-frame scene at 30 fps with two clips windowed 30..90 and 0..120.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/a.mp4'},
          'show': {'from': '30f', 'to': '90f'},
        },
        {
          'id': 'el-b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/b.mp4'},
          'show': {'from': '0f', 'to': '120f'},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history, this.scope);
  final DocumentHistory history;
  final CommandScope scope;
}

_Harness _harness({Set<String> selection = const {}, int playhead = 60, bool transport = true}) {
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  return _Harness(
    history,
    CommandScope(
      document: history.document,
      slide: 0,
      dispatch: history.dispatch,
      playhead: playhead,
      timelineSelection: selection,
      seek: transport ? (_) {} : null,
      setMarks: transport ? ({markIn, markOut}) {} : null,
    ),
  );
}

EditorCommandEntry get _razor => editorCommandById('timeline.razor');

List<String> _clipIds(EditorDocument document) => [
  for (final id in document.elementIdsInScene(0))
    if (document.elementJson(id)!['type'] == 'Clip') id,
];

void main() {
  group('when it is offered', () {
    test('not without a transport, because there is no playhead to cut at', () {
      expect(_razor.enabled(_harness(selection: {'el:el-a'}, transport: false).scope), isFalse);
    });

    test('not without a selection, because a razor needs something to cut', () {
      expect(_razor.enabled(_harness().scope), isFalse);
    });

    test('not when the playhead is outside every selected bar', () {
      expect(_razor.enabled(_harness(selection: {'el:el-a'}, playhead: 10).scope), isFalse);
    });

    test('when one selected bar can be cut', () {
      expect(_razor.enabled(_harness(selection: {'el:el-a'}).scope), isTrue);
    });

    test('when only some of the selected bars can be cut', () {
      // Cutting the ones it can beats refusing the lot: the author asked for
      // a cut here, and the bars that do not reach the playhead are not in
      // the way of the ones that do.
      final harness = _harness(selection: {'el:el-a', 'el:el-b'}, playhead: 10);

      expect(_razor.enabled(harness.scope), isTrue, reason: 'el-b spans the playhead');
    });
  });

  group('cutting', () {
    test('splits one selected bar', () async {
      final harness = _harness(selection: {'el:el-a'});

      await _razor.execute(harness.scope);

      expect(_clipIds(harness.history.document), hasLength(3));
      expect(
        harness.history.document.elementJson('el-a')!['show'],
        {'from': '30f', 'to': '60f'},
      );
    });

    test('splits every selected bar in one undo step', () async {
      final harness = _harness(selection: {'el:el-a', 'el:el-b'});

      await _razor.execute(harness.scope);
      expect(_clipIds(harness.history.document), hasLength(4));

      harness.history.undo();

      expect(_clipIds(harness.history.document), hasLength(2));
      expect(harness.history.canUndo, isFalse, reason: 'one cut, one step');
    });

    test('mints a distinct id per new tail', () async {
      final harness = _harness(selection: {'el:el-a', 'el:el-b'});

      await _razor.execute(harness.scope);

      final ids = _clipIds(harness.history.document);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('leaves the bars the playhead misses alone', () async {
      final harness = _harness(selection: {'el:el-a', 'el:el-b'}, playhead: 10);

      await _razor.execute(harness.scope);

      expect(harness.history.document.elementJson('el-a')!['show'], {'from': '30f', 'to': '90f'});
      expect(_clipIds(harness.history.document), hasLength(3));
    });
  });

  group('the registry contract', () {
    test('it reaches the timeline menu and reads as destructive', () {
      // A razor is not a delete, but it does rewrite what was one clip into
      // two, so the menus print it in the colour that says "this changes
      // content" rather than the colour of a navigation verb.
      expect(_razor.menus, contains(EditorMenu.timeline));
      expect(_razor.destructive, isTrue);
    });

    test('its binding is free of the tool letters', () {
      final entry = editorCommandForKey(_razor.shortcut!.trigger, command: false, shift: false);

      expect(entry?.id, 'timeline.razor');
    });
  });

  group('ripple delete', () {
    EditorCommandEntry ripple() => editorCommandById('timeline.rippleDelete');

    test('is offered only with a selection', () {
      expect(ripple().enabled(_harness().scope), isFalse);
      expect(ripple().enabled(_harness(selection: {'el:el-a'}).scope), isTrue);
    });

    test('needs no playhead, because it acts on the bars and not on time', () {
      expect(
        ripple().enabled(_harness(selection: {'el:el-a'}, transport: false).scope),
        isTrue,
      );
    });

    test('drops the clip and pulls what followed it back', () async {
      final harness = _harness(selection: {'el:el-a'});

      await ripple().execute(harness.scope);

      expect(harness.history.document.elementJson('el-a'), isNull);
      // el-b ran the whole slide, so nothing started after el-a's window and
      // the slide keeps its length.
      expect(_clipIds(harness.history.document), ['el-b']);
    });

    test('is one undo step', () async {
      final harness = _harness(selection: {'el:el-a'});

      await ripple().execute(harness.scope);
      harness.history.undo();

      expect(_clipIds(harness.history.document), ['el-a', 'el-b']);
      expect(harness.history.canUndo, isFalse);
    });
  });
}
