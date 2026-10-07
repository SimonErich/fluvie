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
          'id': 'el-a',
          'type': 'Box',
          'color': '#E17055',
          'transform': {'x': 0.2, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-c',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.8, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

/// A deck whose group is already an arranged row block.
Map<String, Object?> _blockDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-x',
          'type': 'Box',
          'color': '#FDCB6E',
          'transform': {'x': 0.1, 'y': 0.1, 'w': 0.1, 'h': 0.1},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.24, 'y': 0.5, 'w': 0.48, 'h': 1},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.76, 'y': 0.5, 'w': 0.48, 'h': 1},
            },
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-g': {
        'block': {
          'kind': 'row',
          'spacing': 0.04,
          'mainAlign': 'start',
          'crossAlign': 'stretch',
          'equalSize': true,
        },
      },
    },
  },
};

Map<String, Object?> _transformOf(EditorDocument document, String id) =>
    document.elementJson(id)!['transform']! as Map<String, Object?>;

void _expectBox(
  Map<String, Object?> transform, {
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  expect((transform['x']! as num).toDouble(), closeTo(x, 1e-9));
  expect((transform['y']! as num).toDouble(), closeTo(y, 1e-9));
  expect((transform['w']! as num).toDouble(), closeTo(w, 1e-9));
  expect((transform['h']! as num).toDouble(), closeTo(h, 1e-9));
}

void main() {
  group('the document block channel', () {
    test('a null meta value removes its key', () {
      final document = EditorDocument.fromJson(
        _blockDeck(),
      ).setElementMeta('el-g', {'block': null});
      expect(document.elementMeta('el-g'), isEmpty);
    });

    test('blockOf reads the block meta of a group', () {
      final document = EditorDocument.fromJson(_blockDeck());
      expect(document.blockOf('el-g')?.kind, BlockKind.row);
      expect(document.blockOf('el-x'), isNull);
      expect(document.blockOf('missing'), isNull);
    });

    test('block meta on a non-group reads as no block', () {
      final document = EditorDocument.fromJson(_blockDeck()).setElementMeta('el-x', {
        'block': {'kind': 'row'},
      });
      expect(document.blockOf('el-x'), isNull);
    });

    test('reflowing nothing is a no-op', () {
      final document = EditorDocument.fromJson(_blockDeck());
      expect(identical(document.reflowBlock(null), document), isTrue);
      expect(identical(document.reflowBlock('el-x'), document), isTrue);
    });
  });

  group('MakeBlockCommand', () {
    test('groups, tags, and arranges in one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();
      history.dispatch(
        MakeBlockCommand(
          scene: 0,
          ids: const ['el-a', 'el-b'],
          groupId: 'el-g1',
          transform: const {'x': 0.35, 'y': 0.5, 'w': 0.5, 'h': 0.2},
          block: BlockSpec.defaults(BlockKind.row),
        ),
      );
      final document = history.document;
      expect(document.elementIdsInScene(0), ['el-g1', 'el-c']);
      expect(document.childIdsOfGroup('el-g1'), ['el-a', 'el-b']);
      expect(document.blockOf('el-g1')?.kind, BlockKind.row);
      _expectBox(_transformOf(document, 'el-a'), x: 0.24, y: 0.5, w: 0.48, h: 1);
      _expectBox(_transformOf(document, 'el-b'), x: 0.76, y: 0.5, w: 0.48, h: 1);
      history.undo();
      expect(history.document.toJson(), before);
    });

    test('nested blocks arrange the inner block as one box', () {
      var document = EditorDocument.fromJson(_deck());
      document = MakeBlockCommand(
        scene: 0,
        ids: const ['el-a', 'el-b'],
        groupId: 'el-g1',
        transform: const {'x': 0.35, 'y': 0.5, 'w': 0.5, 'h': 0.2},
        block: BlockSpec.defaults(BlockKind.row),
      ).apply(document);
      document = MakeBlockCommand(
        scene: 0,
        ids: const ['el-g1', 'el-c'],
        groupId: 'el-g2',
        transform: const {'x': 0.5, 'y': 0.5, 'w': 0.9, 'h': 0.4},
        block: BlockSpec.defaults(BlockKind.column),
      ).apply(document);
      expect(document.childIdsOfGroup('el-g2'), ['el-g1', 'el-c']);
      // The outer column slots the inner block group like any child box.
      _expectBox(_transformOf(document, 'el-g1'), x: 0.5, y: 0.24, w: 1, h: 0.48);
      _expectBox(_transformOf(document, 'el-c'), x: 0.5, y: 0.76, w: 1, h: 0.48);
      // The inner block's children keep their own arranged fractions.
      _expectBox(_transformOf(document, 'el-a'), x: 0.24, y: 0.5, w: 0.48, h: 1);
      _expectBox(_transformOf(document, 'el-b'), x: 0.76, y: 0.5, w: 0.48, h: 1);
      expect(document.blockOf('el-g1')?.kind, BlockKind.row);
    });
  });

  group('SetBlockParamsCommand', () {
    test('rewrites the params and reflows', () {
      final document = SetBlockParamsCommand(
        groupId: 'el-g',
        block: BlockSpec.fromJson(const {'kind': 'row', 'spacing': 0.1})!,
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.blockOf('el-g')?.spacing, 0.1);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.225, y: 0.5, w: 0.45, h: 1);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.775, y: 0.5, w: 0.45, h: 1);
    });

    test('turns a plain group into a block', () {
      final base = const ClearBlockCommand(ids: ['el-g']).apply(
        EditorDocument.fromJson(_blockDeck()),
      );
      expect(base.blockOf('el-g'), isNull);
      final document = SetBlockParamsCommand(
        groupId: 'el-g',
        block: BlockSpec.defaults(BlockKind.column),
      ).apply(base);
      expect(document.blockOf('el-g')?.kind, BlockKind.column);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.5, y: 0.24, w: 1, h: 0.48);
    });

    test('a merge group coalesces a param stream into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_blockDeck()));
      final before = history.document.toJson();
      history
        ..dispatch(
          SetBlockParamsCommand(
            groupId: 'el-g',
            block: BlockSpec.fromJson(const {'kind': 'row', 'spacing': 0.1})!,
            mergeGroup: 'spacing',
          ),
        )
        ..dispatch(
          SetBlockParamsCommand(
            groupId: 'el-g',
            block: BlockSpec.fromJson(const {'kind': 'row', 'spacing': 0.2})!,
            mergeGroup: 'spacing',
          ),
        );
      expect(history.document.blockOf('el-g')?.spacing, 0.2);
      history.undo();
      expect(history.document.toJson(), before);
      expect(history.canUndo, isFalse);
    });
  });

  group('ClearBlockCommand', () {
    test('drops the meta but keeps the group and its transforms', () {
      final before = EditorDocument.fromJson(_blockDeck());
      final document = const ClearBlockCommand(ids: ['el-g']).apply(before);
      expect(document.blockOf('el-g'), isNull);
      expect(document.childIdsOfGroup('el-g'), ['el-ga', 'el-gb']);
      // The guardrail: the arranged transforms are real spec geometry and
      // survive the block's removal untouched.
      expect(document.elementJson('el-ga'), before.elementJson('el-ga'));
      expect(document.elementJson('el-gb'), before.elementJson('el-gb'));
    });
  });

  group('reflow on mutation', () {
    test('deleting a block child re-balances the remainder', () {
      final document = const RemoveElementCommand(
        id: 'el-ga',
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.childIdsOfGroup('el-g'), ['el-gb']);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.5, y: 0.5, w: 1, h: 1);
    });

    test('deleting outside the block leaves it alone', () {
      final document = const RemoveElementCommand(
        id: 'el-x',
      ).apply(EditorDocument.fromJson(_blockDeck()));
      _expectBox(_transformOf(document, 'el-ga'), x: 0.24, y: 0.5, w: 0.48, h: 1);
    });

    test('deleting a block group drops its block meta', () {
      final document = const RemoveElementCommand(
        id: 'el-g',
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.elementMeta('el-g'), isEmpty);
    });

    test('an equal-size row snaps a resized child back to its slot', () {
      final document = const SetTransformCommand(
        id: 'el-ga',
        transform: {'x': 0.3, 'y': 0.5, 'w': 0.3, 'h': 1},
      ).apply(EditorDocument.fromJson(_blockDeck()));
      _expectBox(_transformOf(document, 'el-ga'), x: 0.24, y: 0.5, w: 0.48, h: 1);
    });

    test('an equal-size-off row keeps a resized main extent and repacks', () {
      var document = SetBlockParamsCommand(
        groupId: 'el-g',
        block: BlockSpec.fromJson(const {'kind': 'row', 'equalSize': false})!,
      ).apply(EditorDocument.fromJson(_blockDeck()));
      document = const SetTransformCommand(
        id: 'el-ga',
        transform: {'x': 0.2, 'y': 0.5, 'w': 0.3, 'h': 1},
      ).apply(document);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.15, y: 0.5, w: 0.3, h: 1);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.58, y: 0.5, w: 0.48, h: 1);
    });

    test('a grid snaps a resized child back to its cell', () {
      var document = SetBlockParamsCommand(
        groupId: 'el-g',
        block: BlockSpec.fromJson(const {'kind': 'grid', 'columns': 2, 'spacing': 0})!,
      ).apply(EditorDocument.fromJson(_blockDeck()));
      document = const SetTransformCommand(
        id: 'el-ga',
        transform: {'x': 0.1, 'y': 0.1, 'w': 0.2, 'h': 0.2},
      ).apply(document);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.25, y: 0.5, w: 0.5, h: 1);
    });

    test('resizing the group scales the arrangement without a rewrite', () {
      final document = const SetTransformCommand(
        id: 'el-g',
        transform: {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.6},
      ).apply(EditorDocument.fromJson(_blockDeck()));
      // The children's fractions are relative to the group, so they hold.
      _expectBox(_transformOf(document, 'el-ga'), x: 0.24, y: 0.5, w: 0.48, h: 1);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.76, y: 0.5, w: 0.48, h: 1);
    });

    test('reordering block children re-slots them', () {
      final document = const ReorderElementCommand(
        id: 'el-ga',
        to: 1,
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.childIdsOfGroup('el-g'), ['el-gb', 'el-ga']);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.24, y: 0.5, w: 0.48, h: 1);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.76, y: 0.5, w: 0.48, h: 1);
    });

    test('the z-order commands re-slot too', () {
      final document = const ArrangeOrderCommand(
        ids: ['el-ga'],
        order: ArrangeOrder.forward,
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.childIdsOfGroup('el-g'), ['el-gb', 'el-ga']);
      _expectBox(_transformOf(document, 'el-gb'), x: 0.24, y: 0.5, w: 0.48, h: 1);
    });

    test('ungrouping a block drops its block meta with the group', () {
      final document = const UngroupElementsCommand(
        ids: ['el-g'],
      ).apply(EditorDocument.fromJson(_blockDeck()));
      expect(document.elementMeta('el-g'), isEmpty);
      expect(document.elementIdsInScene(0), ['el-x', 'el-ga', 'el-gb']);
    });
  });

  group('ReleaseFromBlockCommand', () {
    test('rejects a non-group and a non-child', () {
      final document = EditorDocument.fromJson(_blockDeck());
      expect(
        () => const ReleaseFromBlockCommand(
          groupId: 'el-x',
          childId: 'el-ga',
          transform: {'x': 0.5, 'y': 0.5},
        ).apply(document),
        throwsArgumentError,
      );
      expect(
        () => const ReleaseFromBlockCommand(
          groupId: 'el-g',
          childId: 'el-x',
          transform: {'x': 0.5, 'y': 0.5},
        ).apply(document),
        throwsArgumentError,
      );
    });

    test('promotes the child above the group and re-balances the rest', () {
      final history = DocumentHistory(EditorDocument.fromJson(_blockDeck()));
      final before = history.document.toJson();
      history.dispatch(
        const ReleaseFromBlockCommand(
          groupId: 'el-g',
          childId: 'el-gb',
          transform: {'x': 1.2, 'y': 0.5, 'w': 0.25, 'h': 0.5},
        ),
      );
      final document = history.document;
      expect(document.elementIdsInScene(0), ['el-x', 'el-g', 'el-gb']);
      // The dragged group-relative placement, rewritten to canvas fractions
      // through the same math ungroup promotion uses.
      _expectBox(_transformOf(document, 'el-gb'), x: 0.85, y: 0.5, w: 0.125, h: 0.25);
      expect(document.childIdsOfGroup('el-g'), ['el-ga']);
      _expectBox(_transformOf(document, 'el-ga'), x: 0.5, y: 0.5, w: 1, h: 1);
      history.undo();
      expect(history.document.toJson(), before);
    });
  });
}
