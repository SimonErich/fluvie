// The menu bar over the command registry. Every command-backed item reads one
// registry entry, so the bar cannot advertise a binding that does not fire —
// the same guarantee the context menus and the palette already have.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'hello'},
      ],
    },
  ],
};

CommandScope _scope({
  Set<String> selection = const {},
  void Function(EditorCommand command)? dispatch,
}) => CommandScope(
  document: EditorDocument.fromJson(_deck()),
  slide: 0,
  selection: selection,
  dispatch: dispatch ?? (_) {},
);

const EditorFileActions _noFiles = (
  save: null,
  saveAs: null,
  saveCopy: null,
  exportDart: null,
  exportImages: null,
  exportPdf: null,
  exportVideo: null,
  videoExportNote: null,
  present: null,
  close: null,
);

/// Every command-backed item in the bar, flattened.
List<OiMenuItem> _commandItems(CommandScope scope) => [
  for (final menu in editorMenuBarItems(scope, _noFiles).skip(1))
    ...?menu.children?.whereType<OiMenuItem>(),
];

void main() {
  group('the bar is built from the registry', () {
    test('every command-backed item carries its registry title and hint', () {
      // The sweep: if a label or a binding hint is ever typed into the bar
      // instead of read from the entry, this notices.
      final scope = _scope();
      for (final item in _commandItems(scope)) {
        if (item is OiMenuDivider) continue;
        final entry = editorCommands.firstWhere(
          (candidate) => candidate.title == item.label,
          orElse: () => throw StateError('"${item.label}" is not a registry command'),
        );
        expect(item.shortcut, entry.shortcut?.hint, reason: '${entry.id} hint must match');
        expect(item.destructive, entry.destructive, reason: '${entry.id} destructive must match');
      }
    });

    test('every id the bar names exists in the registry', () {
      // editorCommandById throws on an unknown id, so building the bar at all
      // is the assertion; this states it so a reader knows it is covered.
      expect(() => editorMenuBarItems(_scope(), _noFiles), returnsNormally);
    });

    test('an item disabled for this scope offers no action', () {
      // Nothing is selected, so the clipboard and arrange commands are inert.
      final items = _commandItems(_scope()).where((item) => item is! OiMenuDivider);
      for (final item in items.where((item) => !item.enabled)) {
        expect(item.onTap, isNull, reason: '"${item.label}" is disabled and must not act');
      }
    });

    test('a selection enables what it should and the item then acts', () {
      final dispatched = <EditorCommand>[];
      final scope = _scope(selection: {'el-a'}, dispatch: dispatched.add);

      // Copy needs somewhere to copy TO, so a selection alone does not enable
      // it: a scope with no clipboard leaves it inert rather than failing when
      // tapped.
      final copy = _commandItems(scope).firstWhere((item) => item.label == 'Copy');
      expect(copy.enabled, isFalse);
      expect(copy.onTap, isNull);

      final delete = _commandItems(scope).firstWhere((item) => item.label == 'Delete');
      expect(delete.enabled, isTrue);
      delete.onTap!();
      expect(dispatched, isNotEmpty, reason: 'the menu item runs the registry entry');
    });
  });

  test('Clip and Sequence expose every NLE registry verb', () {
    final menus = editorMenuBarItems(_scope(), _noFiles);
    final labels = {
      for (final menu in menus.where((menu) => ['Clip', 'Sequence'].contains(menu.label)))
        for (final item in menu.children!.whereType<OiMenuItem>()) item.label,
    };
    for (final command in editorCommands.where((entry) => entry.id.startsWith('timeline.'))) {
      expect(labels, contains(command.title), reason: command.id);
    }
  });

  group('the File menu', () {
    test('offers a missing flow disabled rather than hiding it', () {
      final file = editorMenuBarItems(_scope(), _noFiles).first;
      final items = file.children!.whereType<OiMenuItem>().where((i) => i is! OiMenuDivider);

      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.enabled, isFalse);
        expect(item.onTap, isNull);
      }
    });

    test('an unavailable render says what is missing, in the label', () {
      final file = editorMenuBarItems(
        _scope(),
        (
          save: null,
          saveAs: null,
          saveCopy: null,
          exportDart: null,
          exportImages: null,
          exportPdf: null,
          exportVideo: null,
          videoExportNote: 'needs the desktop app',
          present: null,
          close: null,
        ),
      ).first;

      expect(
        file.children!.whereType<OiMenuItem>().map((i) => i.label),
        contains('Export video (needs the desktop app)'),
      );
    });

    test('an available render reads as the plain action', () {
      var exported = 0;
      final file = editorMenuBarItems(
        _scope(),
        (
          save: null,
          saveAs: null,
          saveCopy: null,
          exportDart: null,
          exportImages: null,
          exportPdf: null,
          exportVideo: () => exported++,
          videoExportNote: null,
          present: null,
          close: null,
        ),
      ).first;

      final item = file.children!.whereType<OiMenuItem>().firstWhere(
        (i) => i.label == 'Export video (MP4)',
      );
      expect(item.enabled, isTrue);
      item.onTap!();
      expect(exported, 1);
    });
  });

  testWidgets('the bar mounts every top-level menu', (tester) async {
    await tester.pumpWidget(
      OiApp(
        home: EditorMenuBar(scope: _scope(), files: _noFiles),
      ),
    );
    await tester.pumpAndSettle();

    for (final menu in const ['File', 'Edit', 'Clip', 'Sequence', 'Arrange', 'Deck']) {
      expect(find.text(menu), findsOneWidget, reason: '$menu must be on the bar');
    }
  });
}
