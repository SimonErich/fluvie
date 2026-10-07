import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

CommandScope _scope({
  bool canUndo = false,
  bool canRedo = false,
  void Function()? undo,
  void Function()? redo,
}) => CommandScope(
  document: EditorDocument.fromJson(_deck()),
  slide: 0,
  dispatch: (_) {},
  canUndo: canUndo,
  canRedo: canRedo,
  undo: undo ?? () {},
  redo: redo ?? () {},
);

void main() {
  group('the history commands', () {
    test('undo binds Ctrl+Z and redo binds Ctrl+Shift+Z with Ctrl+Y beside it', () {
      final undo = editorCommandById('edit.undo');
      expect(undo.title, 'Undo');
      expect(undo.shortcut?.hint, 'Ctrl+Z');
      final redo = editorCommandById('edit.redo');
      expect(redo.title, 'Redo');
      expect(redo.shortcut?.hint, 'Ctrl+Shift+Z');
      expect(redo.shortcut!.matches(LogicalKeyboardKey.keyY, command: true, shift: false), isTrue);
    });

    test('the chords resolve through the key dispatch, Ctrl+Y included', () {
      expect(
        editorCommandForKey(LogicalKeyboardKey.keyZ, command: true, shift: false)?.id,
        'edit.undo',
      );
      expect(
        editorCommandForKey(LogicalKeyboardKey.keyZ, command: true, shift: true)?.id,
        'edit.redo',
      );
      expect(
        editorCommandForKey(LogicalKeyboardKey.keyY, command: true, shift: false)?.id,
        'edit.redo',
      );
      // A bare Z stays a free key (no tool binds it either).
      expect(editorCommandForKey(LogicalKeyboardKey.keyZ, command: false, shift: false), isNull);
    });

    test('enabled follows the scope history flags', () {
      final undo = editorCommandById('edit.undo');
      final redo = editorCommandById('edit.redo');
      expect(undo.enabled(_scope()), isFalse);
      expect(redo.enabled(_scope()), isFalse);
      expect(undo.enabled(_scope(canUndo: true)), isTrue);
      expect(redo.enabled(_scope(canRedo: true)), isTrue);
    });

    test('execute calls the scope callables', () async {
      var undone = 0;
      var redone = 0;
      final scope = _scope(
        canUndo: true,
        canRedo: true,
        undo: () => undone++,
        redo: () => redone++,
      );
      await editorCommandById('edit.undo').execute(scope);
      await editorCommandById('edit.redo').execute(scope);
      expect(undone, 1);
      expect(redone, 1);
    });

    test('the scope defaults are inert and disabled', () {
      final scope = CommandScope(
        document: EditorDocument.fromJson(_deck()),
        slide: 0,
        dispatch: (_) {},
      );
      expect(scope.canUndo, isFalse);
      expect(scope.canRedo, isFalse);
      // The inert callables run without effect.
      scope
        ..undo()
        ..redo();
    });

    test('both surface in the canvas menu', () {
      final scope = _scope(canUndo: true, canRedo: true);
      final labels = [for (final item in canvasMenuItems(scope)) item.label];
      expect(labels, containsAllInOrder(['Undo', 'Redo']));
    });
  });
}
