import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {'id': 'el-a', 'type': 'Box', 'color': '#111111'},
        {'id': 'el-b', 'type': 'Box', 'color': '#222222'},
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {'id': 'el-ga', 'type': 'Box', 'color': '#AAAAAA'},
          ],
        },
      ],
    },
  ],
};

void main() {
  group('SetElementsVisibleCommand (hide and show)', () {
    test('hides a multi-selection in one undoable, digest-moving step', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      const command = SetElementsVisibleCommand(ids: ['el-a', 'el-b'], visible: false);
      expect(command.label, 'Hide 2 elements');
      expect(command.affectedIds, {'el-a', 'el-b'});
      history.dispatch(command);
      expect(history.document.elementJson('el-a')?['visible'], false);
      expect(history.document.elementJson('el-b')?['visible'], false);
      expect(history.document.renderDigest, isNot(doc.renderDigest));
      history.undo();
      expect(history.document.toJson(), doc.toJson());
      expect(history.document.renderDigest, doc.renderDigest);
    });

    test('showing removes the flag entirely (canonical elision)', () {
      final doc = EditorDocument.fromJson(
        _deck(),
      ).setElementVisible('el-a', visible: false);
      final history = DocumentHistory(doc);
      const command = SetElementsVisibleCommand(ids: ['el-a'], visible: true);
      expect(command.label, 'Show el-a');
      history.dispatch(command);
      expect(history.document.elementJson('el-a')?.containsKey('visible'), isFalse);
    });

    test('reaches a group child', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetElementsVisibleCommand(ids: ['el-ga'], visible: false));
      expect(history.document.elementJson('el-ga')?['visible'], false);
    });
  });

  group('SetElementsMetaCommand (lock stays editor-block data)', () {
    test('locks a multi-selection in one step without moving the digest', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      const command = SetElementsMetaCommand(ids: ['el-a', 'el-g'], meta: {'locked': true});
      expect(command.label, 'Annotate 2 elements');
      expect(command.affectedIds, {'el-a', 'el-g'});
      history.dispatch(command);
      expect(history.document.elementMeta('el-a')['locked'], isTrue);
      expect(history.document.elementMeta('el-g')['locked'], isTrue);
      expect(history.document.renderDigest, doc.renderDigest);
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });

    test('merges over existing metadata per element', () {
      final doc = EditorDocument.fromJson(_deck()).setElementMeta('el-a', {'name': 'Backdrop'});
      final ids = ['el-a'];
      final history = DocumentHistory(doc)
        ..dispatch(SetElementsMetaCommand(ids: ids, meta: const {'locked': true}));
      expect(history.document.elementMeta('el-a'), {'name': 'Backdrop', 'locked': true});
    });
  });
}
