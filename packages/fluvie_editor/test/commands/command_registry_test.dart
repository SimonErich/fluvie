import 'dart:ui' show Offset, Size;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiMenuDivider, OiMenuItem;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': [
    {'id': 'v1'},
  ],
  'masters': {
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.2, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-z',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
    {
      'duration': '60f',
      'master': 'base',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#E17055',
          'transform': {'x': 0.2, 'y': 0.4, 'w': 0.2, 'h': 0.2},
          // An effect stack, so the effect clipboard verbs are live in the
          // everything-enabled sweep.
          'effects': [
            {'kind': 'grain', 'amount': 0.3},
          ],
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.6, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        // A windowed element on the stage slide, so the razor has a bar it
        // can honestly cut at the playhead.
        {
          'id': 'el-w',
          'type': 'Box',
          'color': '#FFB224',
          'transform': {'x': 0.5, 'y': 0.2, 'w': 0.2, 'h': 0.2},
          'show': {'from': '0f', 'to': '60f'},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.8, 'w': 0.4, 'h': 0.2},
          'children': [
            {
              'id': 'el-gc',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
          ],
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-g': {
        'block': {'kind': 'row'},
      },
    },
  },
};

/// A scope in which every registry command is enabled: three slides with
/// the middle one on stage, a three-element selection including a group,
/// a live clipboard, and a history with steps both ways.
CommandScope _everythingEnabled() {
  final document = EditorDocument.fromJson(_deck());
  final geometry = SceneGeometry.of(document, 1);
  return CommandScope(
    document: document,
    slide: 1,
    selection: {'el-a', 'el-b', 'el-g'},
    clipboard: EditorClipboard(),
    dispatch: (_) {},
    rectOf: geometry.rectOf,
    canUndo: true,
    canRedo: true,
    // A transport with both marks set, so the timeline verbs are live too: the
    // sweep only means something if the scope can serve every command.
    playhead: 90,
    markIn: 70,
    markOut: 100,
    activeLane: 'v1',
    toggleSnap: () {},
    // Slide 1 runs 60..120 on the absolute clock, so a playhead at 90 sits
    // inside the windowed element's bar.
    timelineSelection: {'el:el-w'},
    seek: (_) {},
    setMarks: ({markIn, markOut}) {},
  );
}

/// Every labelled item of [items], submenu children included.
List<OiMenuItem> _flatten(List<OiMenuItem> items) => [
  for (final item in items)
    if (item is! OiMenuDivider) ...[item, ..._flatten(item.children ?? const [])],
];

void main() {
  group('the command registry', () {
    test('ids are unique', () {
      final ids = [for (final entry in editorCommands) entry.id];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every command belongs to at least one context menu', () {
      for (final entry in editorCommands) {
        expect(entry.menus, isNotEmpty, reason: '${entry.id} is unreachable from every menu');
      }
    });

    test('every command appears in the palette with its registered binding', () {
      final scope = _everythingEnabled();
      final palette = paletteCommands(scope);
      for (final entry in editorCommands) {
        final command = palette.where((c) => c.id == entry.id);
        expect(command, hasLength(1), reason: '${entry.id} is missing from the palette');
        expect(command.single.label, entry.title);
        // SingleActivator has no value equality; compare the chord.
        final activator = command.single.shortcut as SingleActivator?;
        final registered = entry.shortcut?.activator;
        expect(activator?.trigger, registered?.trigger, reason: entry.id);
        expect(activator?.control, registered?.control, reason: entry.id);
        expect(activator?.meta, registered?.meta, reason: entry.id);
        expect(activator?.shift, registered?.shift, reason: entry.id);
      }
    });

    test('every command appears in each of its menus with its registered hint', () {
      final scope = _everythingEnabled();
      for (final entry in editorCommands) {
        for (final menu in entry.menus) {
          final items = _flatten(menuItemsFor(menu, scope));
          final matches = items.where((item) => item.label == entry.title);
          expect(matches, hasLength(1), reason: '${entry.id} is missing from $menu');
          expect(
            matches.single.shortcut,
            entry.shortcut?.hint,
            reason: '${entry.id} shows a hint that is not its binding',
          );
        }
      }
    });

    test('menus surface only registry commands', () {
      final scope = _everythingEnabled();
      final titles = {for (final entry in editorCommands) entry.title};
      for (final menu in EditorMenu.values) {
        for (final item in _flatten(menuItemsFor(menu, scope))) {
          if (item.children != null && item.children!.isNotEmpty) continue;
          expect(titles, contains(item.label), reason: '"${item.label}" is not in the registry');
        }
      }
    });

    test('in the everything-enabled scope every command is enabled', () {
      final scope = _everythingEnabled();
      for (final entry in editorCommands) {
        expect(entry.enabled(scope), isTrue, reason: '${entry.id} is disabled');
      }
    });

    test('each registered binding dispatches back to its own entry', () {
      for (final entry in editorCommands) {
        final shortcut = entry.shortcut;
        if (shortcut == null) continue;
        final found = editorCommandForKey(
          shortcut.trigger,
          command: shortcut.command,
          shift: shortcut.shift,
        );
        expect(found?.id, entry.id, reason: "${entry.id}'s binding fires ${found?.id}");
      }
    });

    test('no two commands share a binding, alternates included', () {
      final seen = <String>{};
      void claim(EditorShortcut shortcut, String id) {
        for (final key in [shortcut.trigger, ...shortcut.also]) {
          final chord = '${shortcut.command}:${shortcut.shift}:${key.keyId}';
          expect(seen.add(chord), isTrue, reason: '$id reuses a binding');
        }
        for (final alternate in shortcut.alternates) {
          claim(alternate, id);
        }
      }

      for (final entry in editorCommands) {
        final shortcut = entry.shortcut;
        if (shortcut == null) continue;
        claim(shortcut, entry.id);
      }
    });

    test('an unbound key finds no command', () {
      expect(editorCommandForKey(LogicalKeyboardKey.keyQ, command: false, shift: false), isNull);
      expect(editorCommandForKey(LogicalKeyboardKey.keyC, command: false, shift: false), isNull);
    });
  });

  group('enabled predicates', () {
    CommandScope scopeWith({
      Set<String> selection = const {},
      int slide = 1,
      String? enteredGroup,
      EditorClipboard? clipboard,
      Map<String, Object?>? deck,
    }) {
      final document = EditorDocument.fromJson(deck ?? _deck());
      return CommandScope(
        document: document,
        slide: slide,
        selection: selection,
        enteredGroup: enteredGroup,
        clipboard: clipboard,
        dispatch: (_) {},
        rectOf: SceneGeometry.of(document, slide).rectOf,
      );
    }

    bool enabled(String id, CommandScope scope) => editorCommandById(id).enabled(scope);

    test('cut, copy, duplicate, and delete need a selection', () {
      final empty = scopeWith(clipboard: EditorClipboard());
      for (final id in ['edit.cut', 'edit.copy', 'edit.duplicate', 'edit.delete']) {
        expect(enabled(id, empty), isFalse, reason: id);
      }
      final selected = scopeWith(selection: {'el-a'}, clipboard: EditorClipboard());
      for (final id in ['edit.cut', 'edit.copy', 'edit.duplicate', 'edit.delete']) {
        expect(enabled(id, selected), isTrue, reason: id);
      }
    });

    test('cut, copy, and paste need a clipboard', () {
      final scope = scopeWith(selection: {'el-a'});
      for (final id in ['edit.cut', 'edit.copy', 'edit.paste']) {
        expect(enabled(id, scope), isFalse, reason: id);
      }
    });

    test('select all needs a selectable element', () {
      expect(enabled('edit.selectAll', scopeWith(slide: 2)), isFalse);
      expect(enabled('edit.selectAll', scopeWith()), isTrue);
    });

    test('grouping needs two top-level elements outside an entered group', () {
      expect(enabled('arrange.group', scopeWith(selection: {'el-a'})), isFalse);
      expect(
        enabled('arrange.group', scopeWith(selection: {'el-a', 'el-b'}, enteredGroup: 'el-g')),
        isFalse,
      );
      expect(enabled('arrange.group', scopeWith(selection: {'el-a', 'el-b'})), isTrue);
    });

    test('ungrouping needs a selected group', () {
      expect(enabled('arrange.ungroup', scopeWith(selection: {'el-a', 'el-b'})), isFalse);
      expect(enabled('arrange.ungroup', scopeWith(selection: {'el-g'})), isTrue);
    });

    test('making a block needs two top-level elements outside a group', () {
      expect(enabled('block.row', scopeWith(selection: {'el-a'})), isFalse);
      expect(
        enabled('block.row', scopeWith(selection: {'el-a', 'el-b'}, enteredGroup: 'el-g')),
        isFalse,
      );
      expect(enabled('block.row', scopeWith(selection: {'el-a', 'el-b'})), isTrue);
    });

    test('clearing a block needs a selected block group', () {
      expect(enabled('block.clear', scopeWith(selection: {'el-a'})), isFalse);
      expect(enabled('block.clear', scopeWith(selection: {'el-g'})), isTrue);
    });

    test('distributing needs three elements, aligning one', () {
      expect(enabled('align.left', scopeWith()), isFalse);
      expect(enabled('align.left', scopeWith(selection: {'el-a'})), isTrue);
      expect(enabled('distribute.horizontal', scopeWith(selection: {'el-a', 'el-b'})), isFalse);
      expect(
        enabled('distribute.horizontal', scopeWith(selection: {'el-a', 'el-b', 'el-g'})),
        isTrue,
      );
    });

    test('slide moves stop at the deck edges and delete keeps one slide', () {
      expect(enabled('slide.moveUp', scopeWith(slide: 0)), isFalse);
      expect(enabled('slide.moveUp', scopeWith()), isTrue);
      expect(enabled('slide.moveDown', scopeWith(slide: 2)), isFalse);
      expect(enabled('slide.moveDown', scopeWith()), isTrue);
      final oneSlide = {
        'fluvieSpec': 1,
        'size': {'width': 320, 'height': 180},
        'fps': 30,
        'scenes': [
          {'duration': '60f', 'children': <Object?>[]},
        ],
      };
      expect(enabled('slide.delete', scopeWith(deck: oneSlide, slide: 0)), isFalse);
      expect(enabled('slide.delete', scopeWith()), isTrue);
    });

    test('the lock and hide toggles report their checked state', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setElementMeta('el-a', {'locked': true}).setElementVisible('el-b', visible: false);
      final locked = CommandScope(
        document: document,
        slide: 1,
        selection: const {'el-a'},
        dispatch: (_) {},
      );
      final hidden = CommandScope(
        document: document,
        slide: 1,
        selection: const {'el-b'},
        dispatch: (_) {},
      );
      final plain = CommandScope(
        document: document,
        slide: 1,
        selection: const {'el-g'},
        dispatch: (_) {},
      );
      expect(editorCommandById('object.lock').checked?.call(locked), isTrue);
      expect(editorCommandById('object.lock').checked?.call(plain), isFalse);
      expect(editorCommandById('object.hide').checked?.call(hidden), isTrue);
      expect(editorCommandById('object.hide').checked?.call(plain), isFalse);
    });
  });

  group('the menu templates', () {
    test('the element menu groups align and block under their submenus', () {
      final scope = _everythingEnabled();
      final submenus = elementMenuItems(
        scope,
      ).where((item) => item.children != null && item.children!.isNotEmpty).toList();
      expect([for (final submenu in submenus) submenu.label], ['Align', 'Block']);
      final alignLabels = [
        for (final child in submenus.first.children!)
          if (child is! OiMenuDivider) child.label,
      ];
      expect(alignLabels, contains('Align left'));
      expect(alignLabels, contains('Distribute horizontally'));
      final blockLabels = [
        for (final child in submenus.last.children!)
          if (child is! OiMenuDivider) child.label,
      ];
      expect(blockLabels, contains('Make row block'));
      expect(blockLabels, contains('Make title block'));
      expect(blockLabels, contains('Clear block'));
    });

    test('delete is destructive and disabled items are marked', () {
      final scope = _everythingEnabled();
      final delete = _flatten(elementMenuItems(scope)).singleWhere((i) => i.label == 'Delete');
      expect(delete.destructive, isTrue);
      final document = scope.document;
      final none = CommandScope(document: document, slide: 1, dispatch: (_) {});
      final disabled = _flatten(elementMenuItems(none)).singleWhere((i) => i.label == 'Delete');
      expect(disabled.enabled, isFalse);
    });

    test('the lock toggle shows its checked state', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setElementMeta('el-a', {'locked': true});
      final scope = CommandScope(
        document: document,
        slide: 1,
        selection: const {'el-a'},
        dispatch: (_) {},
      );
      final lock = _flatten(elementMenuItems(scope)).singleWhere((i) => i.label == 'Lock');
      expect(lock.checked, isTrue);
    });

    test('the canvas menu carries history, paste, select all, and the slide actions', () {
      final labels = [
        for (final item in _flatten(canvasMenuItems(_everythingEnabled()))) item.label,
      ];
      expect(labels, [
        'Undo',
        'Redo',
        'Paste',
        'Select all',
        'Add slide',
        'Duplicate slide',
        'Delete slide',
      ]);
    });

    test('the slide strip menu carries the slide clipboard, sections, and the moves', () {
      final labels = [
        for (final item in _flatten(slideStripMenuItems(_everythingEnabled()))) item.label,
      ];
      expect(labels, [
        'Copy slide',
        'Paste slide',
        'Duplicate slide',
        'Delete slide',
        'Start section here',
        'Edit master',
        'Detach master',
        'New master',
        'Move slide up',
        'Move slide down',
      ]);
    });

    test('sections split with dividers', () {
      final items = elementMenuItems(_everythingEnabled());
      expect(items.whereType<OiMenuDivider>(), isNotEmpty);
      expect(items.first, isNot(isA<OiMenuDivider>()));
      expect(items.last, isNot(isA<OiMenuDivider>()));
    });
  });

  group('CommandScope', () {
    test('scope ids follow the entered group', () {
      final document = EditorDocument.fromJson(_deck());
      final top = CommandScope(document: document, slide: 1, dispatch: (_) {});
      expect(top.scopeIds, ['el-a', 'el-b', 'el-w', 'el-g']);
      final entered = CommandScope(
        document: document,
        slide: 1,
        enteredGroup: 'el-g',
        dispatch: (_) {},
      );
      expect(entered.scopeIds, ['el-gc']);
    });

    test('the ordered selection follows document z-order', () {
      final document = EditorDocument.fromJson(_deck());
      final scope = CommandScope(
        document: document,
        slide: 1,
        selection: const {'el-g', 'el-a'},
        dispatch: (_) {},
      );
      expect(scope.orderedSelection, ['el-a', 'el-g']);
    });

    test('the defaults are inert', () {
      final document = EditorDocument.fromJson(_deck());
      final scope = CommandScope(document: document, slide: 1, dispatch: (_) {});
      expect(scope.rectOf('el-a'), isNull);
      scope
        ..select(const {'el-a'})
        ..exitGroup()
        ..showSlide(2);
      expect(scope.canvasSize, const Size(320, 180));
      expect(scope.frameSize, const Size(320, 180));
      expect(scope.frameOrigin, Offset.zero);
    });
  });
}
