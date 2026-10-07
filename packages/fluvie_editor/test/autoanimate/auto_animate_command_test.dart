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
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Fluvie',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.2},
        },
        {
          'id': 'el-old',
          'type': 'Text',
          'text': 'Only here',
          'transform': {'x': 0.5, 'y': 0.1, 'w': 0.8, 'h': 0.1},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-title-2',
          'type': 'Text',
          'text': 'Fluvie',
          'transform': {'x': 0.3, 'y': 0.12, 'w': 0.5, 'h': 0.1},
        },
      ],
    },
  ],
};

void main() {
  group('ApplyAutoAnimateCommand', () {
    test('enabled applies, disabled clears', () {
      final base = EditorDocument.fromJson(_deck());
      final on = const ApplyAutoAnimateCommand(slide: 1, enabled: true).apply(base);
      expect(on.autoAnimateOn(1), isTrue);
      expect(on.elementJson('el-title-2')!['shared'], startsWith('hero-'));
      final off = const ApplyAutoAnimateCommand(slide: 1, enabled: false).apply(on);
      expect(off.toJson(), base.toJson());
    });

    test('is one undo step through the history', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();
      history.dispatch(const ApplyAutoAnimateCommand(slide: 1, enabled: true));
      expect(history.document.autoAnimateOn(1), isTrue);
      history.undo();
      expect(history.document.toJson(), before);
      expect(history.canUndo, isFalse);
    });

    test('labels the undo menu per direction', () {
      expect(const ApplyAutoAnimateCommand(slide: 1, enabled: true).label, 'Auto-animate slide 2');
      expect(
        const ApplyAutoAnimateCommand(slide: 1, enabled: false).label,
        'Clear auto-animate',
      );
      expect(const ApplyAutoAnimateCommand(slide: 1, enabled: true).affectedIds, isEmpty);
    });
  });

  group('LinkSharedCommand', () {
    test('links across the boundary as one undoable step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();
      history.dispatch(
        const LinkSharedCommand(slide: 1, currentId: 'el-title-2', previousId: 'el-old'),
      );
      final linked = history.document;
      expect(linked.sharedPartnerOf(1, 'el-title-2'), 'el-old');
      expect(history.undo(), {'el-title-2'});
      expect(history.document.toJson(), before);
    });

    test('carries its label and affected ids', () {
      const command = LinkSharedCommand(slide: 1, currentId: 'el-a', previousId: 'el-b');
      expect(command.label, 'Link el-a to the previous slide');
      expect(command.affectedIds, {'el-a'});
    });
  });

  group('UnlinkSharedCommand', () {
    test('breaks an auto pair as one undoable step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const ApplyAutoAnimateCommand(slide: 1, enabled: true))
        ..dispatch(const UnlinkSharedCommand(slide: 1, elementId: 'el-title-2'));
      expect(history.document.sharedPartnerOf(1, 'el-title-2'), isNull);
      expect(history.document.elementJson('el-title')!['shared'], isNull);
      expect(history.undo(), {'el-title-2'});
      expect(history.document.sharedPartnerOf(1, 'el-title-2'), 'el-title');
    });

    test('carries its label and affected ids', () {
      const command = UnlinkSharedCommand(slide: 1, elementId: 'el-a');
      expect(command.label, 'Unlink el-a');
      expect(command.affectedIds, {'el-a'});
    });
  });
}
