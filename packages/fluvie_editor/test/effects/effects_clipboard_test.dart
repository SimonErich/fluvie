// Copying an effect stack: the envelope's third kind, and a paste that
// appends deep copies onto another element — across documents too, because
// the envelope travels as clipboard text.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

import '../commands/fake_system_clipboard.dart';

List<Map<String, Object?>> _stack() => [
  {'kind': 'grain', 'amount': 0.35},
  {
    'kind': 'vignette',
    'amount': {
      'values': [0, 0.9],
      'positions': ['0f', '90f'],
    },
  },
];

Map<String, Object?> _deck({List<Object?>? effects}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Box', 'effects': ?effects},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the effects envelope', () {
    test('round-trips through its JSON text', () {
      final envelope = ClipboardEnvelope.effects(_stack());

      expect(envelope.kind, 'effects');
      final parsed = ClipboardEnvelope.tryParse(jsonEncode(envelope.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.kind, 'effects');
      expect(parsed.effects, _stack());
    });

    test('an elements envelope carries no effects and the other way around', () {
      expect(const ClipboardEnvelope(elements: [], sourceIds: {}).effects, isEmpty);
      expect(ClipboardEnvelope.effects(_stack()).elements, isEmpty);
    });

    test('rejects an effects envelope whose list is not one', () {
      expect(
        ClipboardEnvelope.tryParse('{"fluvieClipboard": 1, "kind": "effects", "effects": 3}'),
        isNull,
      );
    });
  });

  group('PasteEffectsCommand', () {
    test('appends the whole stack after what the element already has', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'bloom'},
          ],
        ),
      );
      final next = PasteEffectsCommand(ids: const ['el-a'], effects: _stack()).apply(document);

      final effects = next.elementJson('el-a')!['effects']! as List;
      expect(effects, hasLength(3));
      expect((effects[0]! as Map)['kind'], 'bloom');
      expect((effects[1]! as Map)['kind'], 'grain');
      expect((effects[2]! as Map)['kind'], 'vignette');
    });

    test('pastes deep copies that share no structure with the source', () {
      final source = _stack();
      final next = PasteEffectsCommand(
        ids: const ['el-a'],
        effects: source,
      ).apply(EditorDocument.fromJson(_deck()));

      (source[1]['amount']! as Map<String, Object?>)['values'] = [1, 1];

      final pasted = (next.elementJson('el-a')!['effects']! as List)[1]! as Map;
      expect((pasted['amount']! as Map)['values'], [0, 0.9]);
    });

    test('is one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();

      history
        ..dispatch(PasteEffectsCommand(ids: const ['el-a'], effects: _stack()))
        ..undo();

      expect(history.document.toJson(), before);
    });
  });

  group('across documents', () {
    final fake = FakeSystemClipboard();

    setUp(fake.install);
    tearDown(fake.uninstall);

    test('what one editor copies, another editor pastes', () async {
      final writer = EditorClipboard();
      await writer.write(ClipboardEnvelope.effects(_stack()));

      final reader = EditorClipboard();
      final envelope = await reader.read();

      expect(envelope, isNotNull);
      expect(envelope!.kind, 'effects');
      expect(envelope.effects, _stack());
    });
  });
}
