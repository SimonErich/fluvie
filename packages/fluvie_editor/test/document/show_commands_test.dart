import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({Map<String, Object?>? show}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a', 'show': ?show},
      ],
    },
  ],
};

void main() {
  group('SetShowWindowCommand', () {
    test('writes both bounds in frames form and undoes back to none', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetShowWindowCommand(id: 'el-a', fromFrames: 30, toFrames: 90));
      expect(history.document.elementJson('el-a')!['show'], {'from': '30f', 'to': '90f'});
      history.undo();
      expect(history.document.elementJson('el-a')!.containsKey('show'), isFalse);
    });

    test('rewrites an authored window whole, whatever unit it used', () {
      final history = DocumentHistory(
        EditorDocument.fromJson(_deck(show: {'from': '1s', 'to': '3s'})),
      )..dispatch(const SetShowWindowCommand(id: 'el-a', fromFrames: 0, toFrames: 60));
      expect(history.document.elementJson('el-a')!['show'], {'from': '0f', 'to': '60f'});
      history.undo();
      expect(history.document.elementJson('el-a')!['show'], {'from': '1s', 'to': '3s'});
    });

    test('coalesces a drag through its merge group', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetShowWindowCommand(id: 'el-a', fromFrames: 10, toFrames: 70, mergeGroup: 'd'),
        )
        ..dispatch(
          const SetShowWindowCommand(id: 'el-a', fromFrames: 20, toFrames: 80, mergeGroup: 'd'),
        );
      expect(history.document.elementJson('el-a')!['show'], {'from': '20f', 'to': '80f'});
      history.undo();
      expect(history.document.elementJson('el-a')!.containsKey('show'), isFalse);
      expect(history.canUndo, isFalse);
    });

    test('a standalone command never merges and names its element', () {
      const command = SetShowWindowCommand(id: 'el-a', fromFrames: 0, toFrames: 1);
      expect(command.mergeKey, isNull);
      expect(command.affectedIds, {'el-a'});
      expect(command.label, 'Place el-a in time');
    });
  });
}
