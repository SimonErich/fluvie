import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Two scenes, so every write can prove itself scene-relative: `el-a` lives
/// in scene 1, which starts at absolute frame 60.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-first', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
            {'preset': 'fadeOut', 'duration': '20f'},
          ],
        },
      ],
    },
  ],
};

List<Map<String, Object?>> _animate(EditorDocument document, String id) =>
    (document.elementJson(id)!['animate']! as List).cast<Map<String, Object?>>();

void main() {
  group('SetAnimationDelayCommand', () {
    test('writes the delay in frames form onto the indexed animation', () {
      const command = SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 12);
      final next = command.apply(EditorDocument.fromJson(_deck()));
      final animate = _animate(next, 'el-a');
      expect(animate[0]['delay'], '12f');
      expect(animate[0]['preset'], 'fadeIn');
      expect(animate[0]['duration'], '30f');
      expect(animate[1].containsKey('delay'), isFalse);
      expect(command.label, contains('el-a'));
      expect(command.affectedIds, {'el-a'});
      expect(command.mergeKey, isNull);
    });

    test('a zero delay removes the key instead of writing 0f', () {
      final delayed = const SetAnimationDelayCommand(
        id: 'el-a',
        index: 0,
        delayFrames: 12,
      ).apply(EditorDocument.fromJson(_deck()));
      final cleared = const SetAnimationDelayCommand(
        id: 'el-a',
        index: 0,
        delayFrames: 0,
      ).apply(delayed);
      expect(_animate(cleared, 'el-a')[0].containsKey('delay'), isFalse);
    });

    test('writes scene-relative frames, never absolute deck frames', () {
      // el-a's scene starts at absolute frame 60; a 12-frame retime must
      // write 12f, not 72f — the spec never holds absolute times.
      const command = SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 12);
      final next = command.apply(EditorDocument.fromJson(_deck()));
      final written = _animate(next, 'el-a')[0]['delay']! as String;
      final frames = int.parse(written.substring(0, written.length - 1));
      expect(frames, 12);
      expect(frames, lessThan(120));
    });

    test('a drag coalesces through its merge group into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 4, mergeGroup: 'd1'),
        )
        ..dispatch(
          const SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 9, mergeGroup: 'd1'),
        );
      expect(_animate(history.document, 'el-a')[0]['delay'], '9f');
      history.undo();
      expect(_animate(history.document, 'el-a')[0].containsKey('delay'), isFalse);
      expect(history.canUndo, isFalse);
    });

    test('distinct drags never merge', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 4, mergeGroup: 'd1'),
        )
        ..dispatch(
          const SetAnimationDelayCommand(id: 'el-a', index: 0, delayFrames: 9, mergeGroup: 'd2'),
        )
        ..undo();
      expect(_animate(history.document, 'el-a')[0]['delay'], '4f');
      expect(history.canUndo, isTrue);
    });
  });

  group('SetAnimationDurationCommand', () {
    test('writes the duration in frames form', () {
      const command = SetAnimationDurationCommand(id: 'el-a', index: 1, durationFrames: 18);
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animate(next, 'el-a')[1]['duration'], '18f');
      expect(command.label, contains('el-a'));
      expect(command.affectedIds, {'el-a'});
      expect(command.mergeKey, isNull);
    });

    test('a left-edge trim writes duration and delay together', () {
      const command = SetAnimationDurationCommand(
        id: 'el-a',
        index: 0,
        durationFrames: 24,
        delayFrames: 6,
        mergeGroup: 'd1',
      );
      final next = command.apply(EditorDocument.fromJson(_deck()));
      final animation = _animate(next, 'el-a')[0];
      expect(animation['duration'], '24f');
      expect(animation['delay'], '6f');
      expect(command.mergeKey, isNotNull);
    });

    test('a left-edge trim back to zero delay clears the delay key', () {
      final delayed = const SetAnimationDelayCommand(
        id: 'el-a',
        index: 0,
        delayFrames: 12,
      ).apply(EditorDocument.fromJson(_deck()));
      final trimmed = const SetAnimationDurationCommand(
        id: 'el-a',
        index: 0,
        durationFrames: 42,
        delayFrames: 0,
      ).apply(delayed);
      expect(_animate(trimmed, 'el-a')[0].containsKey('delay'), isFalse);
    });
  });

  group('AddAnimationCommand', () {
    test('appends to an existing animate list', () {
      const command = AddAnimationCommand(id: 'el-a', animation: {'preset': 'pop'});
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animate(next, 'el-a'), hasLength(3));
      expect(_animate(next, 'el-a').last['preset'], 'pop');
      expect(command.label, contains('el-a'));
      expect(command.affectedIds, {'el-a'});
    });

    test('creates the animate list on a still element', () {
      const command = AddAnimationCommand(id: 'el-first', animation: {'preset': 'fadeIn'});
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animate(next, 'el-first').single['preset'], 'fadeIn');
    });
  });

  group('the animation mutations guard their input', () {
    test('an index past the animate list throws', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.updateAnimation('el-a', 5, {'delay': '1f'}), throwsRangeError);
    });

    test('an element without animations rejects an indexed update', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.updateAnimation('el-first', 0, {'delay': '1f'}), throwsRangeError);
    });

    test('an unknown element throws', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.addAnimation('nope', {'preset': 'fadeIn'}), throwsArgumentError);
    });
  });
}
