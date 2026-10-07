// The timeline's transport and marking commands. They act on time rather than
// on the document, so none of them is undoable — moving the playhead is
// navigation, and burying real edits under it would make undo useless.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/commands/command_registry.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

({CommandScope scope, List<int> seeks, List<({int? markIn, int? markOut})> marks}) _scope({
  int playhead = 0,
  int? markIn,
  int? markOut,
  bool withTransport = true,
}) {
  final seeks = <int>[];
  final marks = <({int? markIn, int? markOut})>[];
  return (
    scope: CommandScope(
      document: EditorDocument.fromJson(_deck()),
      slide: 0,
      dispatch: (_) {},
      playhead: playhead,
      markIn: markIn,
      markOut: markOut,
      seek: withTransport ? seeks.add : null,
      setMarks: withTransport
          ? ({markIn, markOut}) => marks.add((markIn: markIn, markOut: markOut))
          : null,
    ),
    seeks: seeks,
    marks: marks,
  );
}

EditorCommandEntry _entry(String id) => editorCommandById(id);

/// The two verbs in this catalog that change the document.
const _edits = {
  'timeline.razor',
  'timeline.rippleDelete',
  'timeline.razorAll',
  'timeline.lift',
  'timeline.extract',
  'timeline.addLane',
  'timeline.deleteLane',
};

void main() {
  group('a surface with no transport', () {
    test('offers every transport verb disabled rather than acting blind', () {
      final harness = _scope(withTransport: false);

      for (final id in const [
        'timeline.markIn',
        'timeline.markOut',
        'timeline.nextEdit',
        'timeline.previousEdit',
      ]) {
        expect(_entry(id).enabled(harness.scope), isFalse, reason: id);
      }
    });

    test('a scope with no transport still reports its playhead as a real frame', () {
      // Zero is a position, not a null, which is why the commands ask whether
      // a transport exists rather than whether the playhead is zero.
      expect(_scope(withTransport: false).scope.playhead, 0);
      expect(_scope(withTransport: false).scope.canSeek, isFalse);
    });
  });

  group('marking', () {
    test('marks in at the playhead', () async {
      final harness = _scope(playhead: 42);

      await _entry('timeline.markIn').execute(harness.scope);

      expect(harness.marks.single, (markIn: 42, markOut: null));
    });

    test('an in point past the out clears the stale out', () async {
      // An inverted span is not a span. The intent — start here — is
      // unambiguous, so the stale mark gives way.
      final harness = _scope(playhead: 80, markOut: 40);

      await _entry('timeline.markIn').execute(harness.scope);

      expect(harness.marks.single, (markIn: 80, markOut: null));
    });

    test('an out point before the in clears the stale in', () async {
      final harness = _scope(playhead: 20, markIn: 60);

      await _entry('timeline.markOut').execute(harness.scope);

      expect(harness.marks.single, (markIn: null, markOut: 20));
    });

    test('a valid pair keeps both', () async {
      final harness = _scope(playhead: 80, markIn: 20);

      await _entry('timeline.markOut').execute(harness.scope);

      expect(harness.marks.single, (markIn: 20, markOut: 80));
    });

    test('clearing is offered only when there is something to clear', () {
      expect(_entry('timeline.clearMarks').enabled(_scope().scope), isFalse);
      expect(_entry('timeline.clearMarks').enabled(_scope(markIn: 5).scope), isTrue);
    });

    test('clearing drops both', () async {
      final harness = _scope(markIn: 10, markOut: 50);

      await _entry('timeline.clearMarks').execute(harness.scope);

      expect(harness.marks.single, (markIn: null, markOut: null));
    });
  });

  group('the marked span', () {
    test('is a span only when both marks make one', () {
      expect(_scope(markIn: 10, markOut: 50).scope.markedSpan, (start: 10, end: 50));
      expect(_scope(markIn: 10).scope.markedSpan, isNull);
      expect(_scope(markOut: 50).scope.markedSpan, isNull);
      expect(_scope(markIn: 50, markOut: 10).scope.markedSpan, isNull);
      expect(_scope(markIn: 10, markOut: 10).scope.markedSpan, isNull);
    });
  });

  group('going to a mark', () {
    test('is offered only when the mark exists', () {
      expect(_entry('timeline.goToIn').enabled(_scope().scope), isFalse);
      expect(_entry('timeline.goToIn').enabled(_scope(markIn: 12).scope), isTrue);
    });

    test('seeks to it', () async {
      final harness = _scope(markIn: 12, markOut: 88);

      await _entry('timeline.goToIn').execute(harness.scope);
      await _entry('timeline.goToOut').execute(harness.scope);

      expect(harness.seeks, [12, 88]);
    });
  });

  group('edit points', () {
    test('are the frames where the picture actually changes', () {
      // Two scenes of 60 and 90 frames with no transition: the boundaries and
      // the ends, deduplicated.
      expect(editPoints(_scope().scope), [0, 60, 150]);
    });

    test('next moves forward and stops at the last one', () {
      expect(nextEditPoint(_scope().scope), 60);
      expect(nextEditPoint(_scope(playhead: 59).scope), 60);
      expect(nextEditPoint(_scope(playhead: 60).scope), 150);
      expect(nextEditPoint(_scope(playhead: 150).scope), isNull);
    });

    test('previous moves back and stops at the first one', () {
      expect(previousEditPoint(_scope(playhead: 150).scope), 60);
      expect(previousEditPoint(_scope(playhead: 61).scope), 60);
      expect(previousEditPoint(_scope(playhead: 60).scope), 0);
      expect(previousEditPoint(_scope().scope), isNull);
    });

    test('the verbs are disabled at the ends rather than seeking nowhere', () {
      expect(_entry('timeline.nextEdit').enabled(_scope(playhead: 150).scope), isFalse);
      expect(_entry('timeline.previousEdit').enabled(_scope().scope), isFalse);
      expect(_entry('timeline.nextEdit').enabled(_scope().scope), isTrue);
    });

    test('seeking lands exactly on the point', () async {
      final harness = _scope(playhead: 10);

      await _entry('timeline.nextEdit').execute(harness.scope);

      expect(harness.seeks, [60]);
    });
  });

  group('the registry contract', () {
    test('every timeline command is reachable from the timeline menu', () {
      final timeline = editorCommands.where((entry) => entry.id.startsWith('timeline.'));

      expect(timeline, isNotEmpty);
      for (final entry in timeline) {
        expect(entry.menus, contains(EditorMenu.timeline), reason: entry.id);
      }
    });

    test('the transport verbs are not destructive, because none of them is an edit', () {
      // The razor and the ripple delete live in this catalog too and are
      // edits; every other verb here moves the playhead or a mark and changes
      // no content at all.
      for (final entry in editorCommands.where(
        (e) => e.id.startsWith('timeline.') && !_edits.contains(e.id),
      )) {
        expect(entry.destructive, isFalse, reason: entry.id);
      }
    });

    test('none of the transport verbs dispatches a document command', () async {
      final dispatched = <EditorCommand>[];
      final scope = CommandScope(
        document: EditorDocument.fromJson(_deck()),
        slide: 0,
        dispatch: dispatched.add,
        playhead: 30,
        markIn: 10,
        markOut: 50,
        seek: (_) {},
        setMarks: ({markIn, markOut}) {},
      );

      for (final entry in editorCommands.where(
        (e) => e.id.startsWith('timeline.') && !_edits.contains(e.id),
      )) {
        await entry.execute(scope);
      }

      expect(dispatched, isEmpty, reason: 'navigation must not land on the undo stack');
    });
  });
}
