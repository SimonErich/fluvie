import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/rendering.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show decodePlacement;
import 'package:fluvie_editor/fluvie_editor.dart';

const Size _frame = Size(320, 180);

const Rect _a = Rect.fromLTRB(48, 36, 112, 72);
const Rect _b = Rect.fromLTRB(128, 72, 192, 108);
const Rect _c = Rect.fromLTRB(240, 108, 304, 144);

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
          'color': '#111111',
          'transform': {'x': 0.25, 'y': 0.3, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#222222',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-c',
          'type': 'Box',
          'color': '#333333',
          'transform': {'x': 0.85, 'y': 0.7, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-t',
          'type': 'Text',
          'text': 'intrinsic',
          'transform': {'x': 0.5, 'y': 0.1},
        },
      ],
    },
  ],
};

void main() {
  group('alignDeltas', () {
    test('nothing to align yields nothing', () {
      expect(alignDeltas(const {}, AlignEdge.left, _frame), isEmpty);
    });

    test('two or more rects align against the selection bounds', () {
      final deltas = alignDeltas(const {'a': _a, 'b': _b, 'c': _c}, AlignEdge.left, _frame);
      expect(deltas, {
        'a': Offset.zero,
        'b': const Offset(-80, 0),
        'c': const Offset(-192, 0),
      });
    });

    test('centers split the selection bounds', () {
      final deltas = alignDeltas(const {'a': _a, 'b': _b, 'c': _c}, AlignEdge.centerX, _frame);
      expect(deltas['a'], const Offset(96, 0));
      expect(deltas['b'], const Offset(16, 0));
      expect(deltas['c'], const Offset(-96, 0));
    });

    test('a single rect aligns against the frame (the slide)', () {
      expect(
        alignDeltas(const {'a': _a}, AlignEdge.left, _frame),
        {'a': const Offset(-48, 0)},
      );
      expect(
        alignDeltas(const {'a': _a}, AlignEdge.centerX, _frame),
        {'a': const Offset(80, 0)},
      );
      expect(
        alignDeltas(const {'a': _a}, AlignEdge.bottom, _frame),
        {'a': const Offset(0, 108)},
      );
    });

    test('vertical edges move only vertically', () {
      final top = alignDeltas(const {'a': _a, 'c': _c}, AlignEdge.top, _frame);
      expect(top, {'a': Offset.zero, 'c': const Offset(0, -72)});
      final middle = alignDeltas(const {'a': _a, 'c': _c}, AlignEdge.centerY, _frame);
      expect(middle['a'], const Offset(0, 36));
      expect(middle['c'], const Offset(0, -36));
      final right = alignDeltas(const {'a': _a, 'c': _c}, AlignEdge.right, _frame);
      expect(right, {'a': const Offset(192, 0), 'c': Offset.zero});
      final bottom = alignDeltas(const {'a': _a, 'c': _c}, AlignEdge.bottom, _frame);
      expect(bottom, {'a': const Offset(0, 72), 'c': Offset.zero});
    });
  });

  group('distributeDeltas', () {
    test('equal gaps along the horizontal axis, first and last pinned', () {
      final deltas = distributeDeltas(const {'a': _a, 'b': _b, 'c': _c}, Axis.horizontal);
      expect(deltas['a'], Offset.zero);
      expect(deltas['b'], const Offset(16, 0));
      expect(deltas['c'], Offset.zero);
    });

    test('equal gaps along the vertical axis', () {
      final deltas = distributeDeltas(const {'a': _a, 'b': _b, 'c': _c}, Axis.vertical);
      // Span 36..144, sizes 3x36, free 0 -> gap 0: b lands at 72 (no move).
      expect(deltas['b'], Offset.zero);
    });

    test('needs three or more rects', () {
      expect(
        () => distributeDeltas(const {'a': _a, 'b': _b}, Axis.horizontal),
        throwsArgumentError,
      );
    });
  });

  group('AlignElementsCommand', () {
    test('aligns a multi-selection in one undoable step', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      const command = AlignElementsCommand(
        rects: {'el-a': _a, 'el-b': _b, 'el-c': _c},
        edge: AlignEdge.left,
        frame: _frame,
      );
      expect(command.label, 'Align left');
      expect(command.affectedIds, {'el-a', 'el-b', 'el-c'});
      history.dispatch(command);
      for (final id in ['el-a', 'el-b', 'el-c']) {
        final placement = decodePlacement(history.document.elementJson(id)!['transform']);
        expect(placement.rectFor(_frame)!.left, closeTo(48, 1e-6), reason: id);
      }
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });

    test('a single element aligns to the slide', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc)
        ..dispatch(
          const AlignElementsCommand(rects: {'el-a': _a}, edge: AlignEdge.right, frame: _frame),
        );
      final placement = decodePlacement(history.document.elementJson('el-a')!['transform']);
      expect(placement.rectFor(_frame)!.right, closeTo(320, 1e-6));
    });

    test('an intrinsic element shifts its anchor and stays intrinsic', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      // The caller resolved the laid-out rect: 40x18 centered on (160, 18).
      const rect = Rect.fromLTWH(140, 9, 40, 18);
      history.dispatch(
        const AlignElementsCommand(rects: {'el-t': rect}, edge: AlignEdge.left, frame: _frame),
      );
      final placement = decodePlacement(history.document.elementJson('el-t')!['transform']);
      expect(placement.isIntrinsic, isTrue);
      expect(placement.x, closeTo(20 / 320, 1e-9));
      expect(placement.y, closeTo(0.1, 1e-9));
    });

    test('every edge carries its own label', () {
      AlignElementsCommand command(AlignEdge edge) =>
          AlignElementsCommand(rects: const {'el-a': _a}, edge: edge, frame: _frame);
      expect(command(AlignEdge.centerX).label, 'Align center');
      expect(command(AlignEdge.right).label, 'Align right');
      expect(command(AlignEdge.top).label, 'Align top');
      expect(command(AlignEdge.centerY).label, 'Align middle');
      expect(command(AlignEdge.bottom).label, 'Align bottom');
    });
  });

  group('DistributeElementsCommand', () {
    test('distributes in one undoable step', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      // Built at runtime, the way a caller resolves rects from geometry.
      final rects = {'el-a': _a, 'el-b': _b, 'el-c': _c};
      final command = DistributeElementsCommand(
        rects: rects,
        axis: Axis.horizontal,
        frame: _frame,
      );
      expect(command.label, 'Distribute horizontally');
      expect(command.affectedIds, {'el-a', 'el-b', 'el-c'});
      history.dispatch(command);
      final placement = decodePlacement(history.document.elementJson('el-b')!['transform']);
      expect(placement.rectFor(_frame)!.left, closeTo(144, 1e-6));
      // The outer elements never move.
      expect(
        history.document.elementJson('el-a')?['transform'],
        doc.elementJson('el-a')?['transform'],
      );
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });

    test('the vertical axis carries its own label', () {
      expect(
        const DistributeElementsCommand(rects: {}, axis: Axis.vertical, frame: _frame).label,
        'Distribute vertically',
      );
    });
  });
}
