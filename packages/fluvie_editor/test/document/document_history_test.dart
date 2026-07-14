import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          'transform': {'x': 0.5, 'y': 0.5},
        },
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
  ],
};

DocumentHistory _history() => DocumentHistory(EditorDocument.fromJson(_deck()));

void main() {
  group('dispatch', () {
    test('applies the command and records one undo step', () {
      final history = _history()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1}));
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.1, 'y': 0.1});
      expect(history.canUndo, isTrue);
      expect(history.undoLabel, 'Move el-a');
    });

    test('undo restores the previous document and redo replays it', () {
      final history = _history()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1}));
      final affected = history.undo();
      expect(affected, {'el-a'});
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.5, 'y': 0.5});
      expect(history.canRedo, isTrue);
      history.redo();
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.1, 'y': 0.1});
    });

    test('a new dispatch clears the redo branch', () {
      final history = _history()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1}))
        ..undo()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.9, 'y': 0.9}));
      expect(history.canRedo, isFalse);
    });

    test('undo and redo on an empty history are safe no-ops', () {
      final history = _history();
      expect(history.undo(), isEmpty);
      expect(history.redo(), isEmpty);
    });
  });

  group('coalescing', () {
    test('a drag stream of transforms merges into one undo step', () {
      final history = _history();
      for (var i = 1; i <= 5; i++) {
        history.dispatch(
          SetTransformCommand(id: 'el-a', transform: {'x': i / 10, 'y': i / 10}),
        );
      }
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.5, 'y': 0.5});
      history.undo();
      // One undo lands back on the original, not on an intermediate frame.
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.5, 'y': 0.5});
      expect(history.canUndo, isFalse);
    });

    test('different elements never merge', () {
      final history = _history()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1}))
        ..dispatch(const SetTransformCommand(id: 'el-b', transform: {'x': 0.2, 'y': 0.2}))
        ..undo();
      expect(history.document.elementJson('el-b')?.containsKey('transform'), isFalse);
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.1, 'y': 0.1});
      expect(history.canUndo, isTrue);
    });

    test('a non-mergeable command between transforms breaks the run', () {
      final history = _history()
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1}))
        ..dispatch(const RemoveElementCommand(id: 'el-b'))
        ..dispatch(const SetTransformCommand(id: 'el-a', transform: {'x': 0.3, 'y': 0.3}))
        ..undo()
        ..undo();
      expect(history.document.elementJson('el-b'), isNotNull);
      expect(history.document.elementJson('el-a')?['transform'], {'x': 0.1, 'y': 0.1});
    });
  });

  group('the command set', () {
    test('insert keeps its minted id stable across undo and redo', () {
      final history = _history();
      final id = history.document.nextId();
      history.dispatch(
        InsertElementCommand(scene: 0, element: const {'type': 'Text', 'text': 'new'}, id: id),
      );
      expect(history.document.elementIdsInScene(0).last, id);
      history
        ..undo()
        ..redo();
      expect(history.document.elementIdsInScene(0).last, id);
    });

    test('remove, reorder, replace, meta, and scene commands round-trip', () {
      final history = _history();
      final before = history.document.toJson();
      history
        ..dispatch(const ReplaceElementCommand(id: 'el-a', element: {'type': 'Text', 'text': 'A'}))
        ..dispatch(const RemoveElementCommand(id: 'el-b'))
        ..dispatch(const ReorderElementCommand(id: 'el-a', to: 0))
        ..dispatch(const SetElementMetaCommand(id: 'el-a', meta: {'name': 'Title'}))
        ..dispatch(const AddSceneCommand(scene: {'duration': '10f', 'children': <Object?>[]}))
        ..dispatch(const ReorderSceneCommand(from: 1, to: 0))
        ..dispatch(const RemoveSceneCommand(index: 0));
      while (history.canUndo) {
        history.undo();
      }
      expect(history.document.toJson(), before);
    });

    test('every command names its label and affected ids', () {
      expect(const SetTransformCommand(id: 'x', transform: {}).label, isNotEmpty);
      expect(const RemoveElementCommand(id: 'x').affectedIds, {'x'});
      expect(const AddSceneCommand(scene: {}).affectedIds, isEmpty);
    });
  });
}
