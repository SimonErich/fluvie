import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({bool adopt = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': <String, Object?>{
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      if (adopt) 'master': 'base',
      'fills': adopt
          ? {
              'title': {'id': 'el-t', 'type': 'Text', 'text': 'Filled'},
            }
          : null,
      'children': <Object?>[],
    }..removeWhere((key, value) => value == null),
  ],
};

final class _Scope {
  _Scope(Map<String, Object?> deck, {Set<String> selection = const {}}) {
    document = EditorDocument.fromJson(deck);
    scope = CommandScope(
      document: document,
      slide: 0,
      selection: selection,
      dispatch: commands.add,
      editMaster: edited.add,
    );
  }

  late final EditorDocument document;
  late final CommandScope scope;
  final List<EditorCommand> commands = [];
  final List<String> edited = [];
}

void main() {
  group('master.new', () {
    test('is always enabled, writes a starter master, and enters edit mode', () async {
      final harness = _Scope(_deck(adopt: false));
      final entry = editorCommandById('master.new');
      expect(entry.enabled(harness.scope), isTrue);
      await entry.execute(harness.scope);
      final command = harness.commands.single as SetMasterCommand;
      // The starter master offers a title and a body slot.
      final slots = [
        for (final child in command.master!['children']! as List) (child! as Map)['slot'],
      ];
      expect(slots, ['title', 'body']);
      expect(harness.edited, [command.name]);
      // The minted name is a legal identifier free in the document.
      expect(command.name, matches(r'^master\d+$'));
      expect(harness.document.masterNames, isNot(contains(command.name)));
    });

    test('mints past taken names', () async {
      final deck = _deck(adopt: false);
      (deck['masters']! as Map<String, Object?>)['master1'] = {'children': <Object?>[]};
      final harness = _Scope(deck);
      await editorCommandById('master.new').execute(harness.scope);
      expect((harness.commands.single as SetMasterCommand).name, 'master2');
    });
  });

  group('master.edit', () {
    test('needs an adopting slide and hands the master to the surface', () async {
      final adopted = _Scope(_deck());
      final entry = editorCommandById('master.edit');
      expect(entry.enabled(adopted.scope), isTrue);
      await entry.execute(adopted.scope);
      expect(adopted.edited, ['base']);
      expect(adopted.commands, isEmpty);

      final freeform = _Scope(_deck(adopt: false));
      expect(entry.enabled(freeform.scope), isFalse);
    });
  });

  group('master.detach', () {
    test('needs an adopting slide and dispatches the detach', () async {
      final adopted = _Scope(_deck());
      final entry = editorCommandById('master.detach');
      expect(entry.enabled(adopted.scope), isTrue);
      await entry.execute(adopted.scope);
      final command = adopted.commands.single as DetachMasterCommand;
      expect(command.slide, 0);

      final freeform = _Scope(_deck(adopt: false));
      expect(entry.enabled(freeform.scope), isFalse);
    });
  });

  group('fills and the selection commands', () {
    test('delete removes a selected fill', () async {
      final harness = _Scope(_deck(), selection: {'el-t'});
      await editorCommandById('edit.delete').execute(harness.scope);
      final command = harness.commands.single as RemoveElementsCommand;
      expect(command.ids, ['el-t']);
      expect(command.apply(harness.document).elementJson('el-t'), isNull);
    });

    test('selected fills ride behind the ordered selection', () {
      final harness = _Scope(_deck(), selection: {'el-t'});
      expect(harness.scope.orderedSelection, isEmpty, reason: 'fills stay off z-order surfaces');
      expect(harness.scope.selectedFills, ['el-t']);
    });
  });

  test('the scope editMaster default is inert', () {
    final document = EditorDocument.fromJson(_deck());
    final scope = CommandScope(document: document, slide: 0, dispatch: (_) {});
    scope.editMaster('base');
    expect(scope.selectedFills, isEmpty);
  });
}
