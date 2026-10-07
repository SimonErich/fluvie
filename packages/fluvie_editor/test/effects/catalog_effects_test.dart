// The registry's effect-stack verbs: copy the selected element's stack into
// the envelope, paste an effects envelope onto the selected element.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

import '../commands/fake_system_clipboard.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'effects': [
            {'kind': 'grain', 'amount': 0.35},
          ],
        },
        {'id': 'el-b', 'type': 'Box'},
      ],
    },
  ],
};

final class _Scope {
  _Scope({Set<String> selection = const {}}) {
    document = EditorDocument.fromJson(_deck());
    scope = CommandScope(
      document: document,
      slide: 0,
      selection: selection,
      dispatch: commands.add,
      clipboard: clipboard,
    );
  }

  late final EditorDocument document;
  late final CommandScope scope;
  final EditorClipboard clipboard = EditorClipboard();
  final List<EditorCommand> commands = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fake = FakeSystemClipboard();
  setUp(fake.install);
  tearDown(fake.uninstall);

  group('effect.copy', () {
    test('needs a selected element that has effects', () {
      final entry = editorCommandById('effect.copy');

      expect(entry.enabled(_Scope(selection: const {'el-a'}).scope), isTrue);
      expect(entry.enabled(_Scope(selection: const {'el-b'}).scope), isFalse);
      expect(entry.enabled(_Scope(selection: const {'el-a', 'el-b'}).scope), isTrue);
      expect(entry.enabled(_Scope().scope), isFalse);
    });

    test('writes the z-order-first stack into an effects envelope', () async {
      final harness = _Scope(selection: const {'el-a', 'el-b'});
      await editorCommandById('effect.copy').execute(harness.scope);

      final envelope = await harness.clipboard.read();
      expect(envelope!.kind, 'effects');
      expect(envelope.effects.single['kind'], 'grain');
      expect(harness.commands, isEmpty);
    });
  });

  group('effect.paste', () {
    test('appends the envelope onto the selected element as one command', () async {
      final harness = _Scope(selection: const {'el-b'});
      await harness.clipboard.write(
        const ClipboardEnvelope.effects([
          {'kind': 'bloom', 'amount': 0.4},
        ]),
      );

      await editorCommandById('effect.paste').execute(harness.scope);

      final command = harness.commands.single as PasteEffectsCommand;
      expect(command.ids, ['el-b']);
      expect(command.effects.single['kind'], 'bloom');
    });

    test('does nothing for an envelope of another kind', () async {
      final harness = _Scope(selection: const {'el-b'});
      await harness.clipboard.write(
        const ClipboardEnvelope(elements: [], sourceIds: {}),
      );

      await editorCommandById('effect.paste').execute(harness.scope);

      expect(harness.commands, isEmpty);
    });
  });
}
