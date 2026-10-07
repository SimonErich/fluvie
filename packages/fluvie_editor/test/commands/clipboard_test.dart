import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

import 'fake_system_clipboard.dart';

List<Map<String, Object?>> _copiedSet() => [
  {
    'id': 'el-1',
    'type': 'Box',
    'color': '#E17055',
    'anchor': 'intro',
    'transform': {'x': 0.2, 'y': 0.5, 'w': 0.2, 'h': 0.2},
  },
  {
    'id': 'el-2',
    'type': 'Group',
    'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    'children': [
      {
        'id': 'el-3',
        'type': 'Box',
        'color': '#6C5CE7',
        'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        'animate': [
          {
            'preset': 'fadeIn',
            'at': {'kind': 'whenEnds', 'anchor': 'intro'},
          },
          {
            'preset': 'slideIn',
            'at': {'kind': 'whenStarts', 'anchor': 'outside'},
          },
        ],
      },
    ],
  },
];

void main() {
  group('ClipboardEnvelope', () {
    test('round-trips through its JSON text', () {
      final envelope = ClipboardEnvelope(
        elements: _copiedSet(),
        sourceIds: const {'el-1', 'el-2', 'el-3'},
      );
      final parsed = ClipboardEnvelope.tryParse(jsonEncode(envelope.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.elements, envelope.elements);
      expect(parsed.sourceIds, {'el-1', 'el-2', 'el-3'});
    });

    test('rejects text that is not an envelope', () {
      expect(ClipboardEnvelope.tryParse(null), isNull);
      expect(ClipboardEnvelope.tryParse(''), isNull);
      expect(ClipboardEnvelope.tryParse('plain text'), isNull);
      expect(ClipboardEnvelope.tryParse('{"other": 1}'), isNull);
      expect(ClipboardEnvelope.tryParse('{"fluvieClipboard": 2, "elements": []}'), isNull);
      expect(ClipboardEnvelope.tryParse('[1, 2]'), isNull);
    });
  });

  group('the slides envelope', () {
    Map<String, Object?> scene() => const {
      'duration': '60f',
      'children': [
        {'id': 'el-1', 'type': 'Text', 'text': 'hello'},
      ],
    };

    test('round-trips scene and meta through its JSON text', () {
      final envelope = ClipboardEnvelope.slides([
        CopiedSlide(
          scene: scene(),
          meta: const {
            'guides': [
              {'axis': 'vertical', 'pos': 0.5},
            ],
          },
        ),
      ]);
      expect(envelope.kind, 'slides');
      final parsed = ClipboardEnvelope.tryParse(jsonEncode(envelope.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.kind, 'slides');
      expect(parsed.slides.single.scene, scene());
      expect(parsed.slides.single.meta, {
        'guides': [
          {'axis': 'vertical', 'pos': 0.5},
        ],
      });
      expect(parsed.elements, isEmpty);
    });

    test('a slide copied without meta round-trips an empty meta map', () {
      final envelope = ClipboardEnvelope.slides([CopiedSlide(scene: scene())]);
      final parsed = ClipboardEnvelope.tryParse(jsonEncode(envelope.toJson()));
      expect(parsed!.slides.single.meta, isEmpty);
    });

    test('an elements envelope carries no slides', () {
      final envelope = ClipboardEnvelope(elements: _copiedSet(), sourceIds: const {'el-1'});
      expect(envelope.kind, 'elements');
      expect(envelope.slides, isEmpty);
      final parsed = ClipboardEnvelope.tryParse(jsonEncode(envelope.toJson()));
      expect(parsed!.slides, isEmpty);
    });

    test('rejects a slides envelope without its payload and skips junk entries', () {
      expect(ClipboardEnvelope.tryParse('{"fluvieClipboard": 1, "kind": "slides"}'), isNull);
      final parsed = ClipboardEnvelope.tryParse(
        '{"fluvieClipboard": 1, "kind": "slides", '
        '"slides": [7, {"meta": {}}, {"scene": {"duration": "1s"}}]}',
      );
      expect(parsed, isNotNull);
      expect(parsed!.slides, hasLength(1));
      expect(parsed.slides.single.scene, {'duration': '1s'});
    });
  });

  group('remintedElements', () {
    test('every element gets a fresh id, nested group children included', () {
      var counter = 0;
      final reminted = remintedElements(
        _copiedSet(),
        mintId: () => 'new-${++counter}',
        mintAnchorId: (old) => old,
      );
      expect(reminted[0]['id'], 'new-1');
      expect(reminted[1]['id'], 'new-2');
      final children = reminted[1]['children']! as List<Object?>;
      expect((children.first! as Map<String, Object?>)['id'], 'new-3');
    });

    test('leaves the originals untouched', () {
      final source = _copiedSet();
      remintedElements(source, mintId: () => 'new', mintAnchorId: (old) => '$old-2');
      expect(source[0]['id'], 'el-1');
      expect(source[0]['anchor'], 'intro');
    });

    test('re-mints in-set anchor references consistently and preserves escaping ones', () {
      var counter = 0;
      final reminted = remintedElements(
        _copiedSet(),
        mintId: () => 'new-${++counter}',
        mintAnchorId: (old) => '$old-2',
      );
      expect(reminted[0]['anchor'], 'intro-2');
      final children = reminted[1]['children']! as List<Object?>;
      final animate = (children.first! as Map<String, Object?>)['animate']! as List<Object?>;
      final inSet = animate[0]! as Map<String, Object?>;
      final escaping = animate[1]! as Map<String, Object?>;
      expect((inSet['at']! as Map<String, Object?>)['anchor'], 'intro-2');
      expect((escaping['at']! as Map<String, Object?>)['anchor'], 'outside');
    });

    test('a beat track reference follows its in-set anchor', () {
      final reminted = remintedElements(
        [
          {'id': 'el-1', 'type': 'Box', 'color': '#FFF', 'anchor': 'beatline'},
          {
            'id': 'el-2',
            'type': 'Box',
            'color': '#000',
            'animate': [
              {
                'preset': 'pulse',
                'at': {'kind': 'beat', 'every': 2, 'track': 'beatline'},
              },
            ],
          },
        ],
        mintId: () => 'x',
        mintAnchorId: (old) => '$old-9',
      );
      final animate = reminted[1]['animate']! as List<Object?>;
      final at = (animate.first! as Map<String, Object?>)['at']! as Map<String, Object?>;
      expect(at['track'], 'beatline-9');
    });
  });

  group('EditorClipboard', () {
    testWidgets('writes the envelope to the system clipboard and reads it back', (tester) async {
      String? stored;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          stored = (call.arguments as Map<Object?, Object?>)['text']! as String;
          return null;
        }
        if (call.method == 'Clipboard.getData') return {'text': stored};
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final clipboard = EditorClipboard();
      await clipboard.write(ClipboardEnvelope(elements: _copiedSet(), sourceIds: const {'el-1'}));
      expect(stored, isNotNull);

      // A second service instance (another document) reads what the first wrote.
      final other = EditorClipboard();
      final read = await other.read();
      expect(read, isNotNull);
      expect(read!.elements, _copiedSet());
    });

    testWidgets('falls back to memory when the platform clipboard fails', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        throw PlatformException(code: 'denied');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final clipboard = EditorClipboard();
      final envelope = ClipboardEnvelope(elements: _copiedSet(), sourceIds: const {'el-1'});
      await clipboard.write(envelope);
      final read = await clipboard.read();
      expect(read, isNotNull);
      expect(read!.sourceIds, {'el-1'});
    });

    testWidgets('an empty clipboard reads null', (tester) async {
      final fake = FakeSystemClipboard()..install();
      addTearDown(fake.uninstall);
      final clipboard = EditorClipboard();
      expect(await clipboard.read(), isNull);
    });

    testWidgets('foreign clipboard text falls back to memory', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.getData') return {'text': 'someone else wrote this'};
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final clipboard = EditorClipboard();
      final envelope = ClipboardEnvelope(elements: _copiedSet(), sourceIds: const {'el-1'});
      await clipboard.write(envelope);
      final read = await clipboard.read();
      expect(read, isNotNull);
      expect(read!.sourceIds, {'el-1'});
    });
  });
}
