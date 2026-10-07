import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// A child element JSON with an optional relative transform.
Map<String, Object?> _child(String id, [Map<String, Object?>? transform]) => {
  'id': id,
  'type': 'Box',
  'transform': ?transform,
};

Matcher _near(double value) => closeTo(value, 1e-9);

void _expectBox(
  Map<String, Object?>? transform, {
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  expect(transform, isNotNull);
  expect(transform!['x'], _near(x));
  expect(transform['y'], _near(y));
  expect(transform['w'], _near(w));
  expect(transform['h'], _near(h));
}

void main() {
  group('row', () {
    test('equal-size children share the axis minus the gaps', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.row), [
        _child('a'),
        _child('b'),
        _child('c'),
      ]);
      const w = (1 - 0.08) / 3;
      _expectBox(out['a'], x: w / 2, y: 0.5, w: w, h: 1);
      _expectBox(out['b'], x: 0.5, y: 0.5, w: w, h: 1);
      _expectBox(out['c'], x: 1 - w / 2, y: 0.5, w: w, h: 1);
    });

    test('a single child fills the whole box', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.row), [_child('a')]);
      _expectBox(out['a'], x: 0.5, y: 0.5, w: 1, h: 1);
    });

    test('no children reflow to nothing', () {
      expect(reflowedBlockTransforms(BlockSpec.defaults(BlockKind.row), const []), isEmpty);
    });

    test('equal-size off keeps stored main extents and centers the run', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({
          'kind': 'row',
          'spacing': 0.1,
          'mainAlign': 'center',
          'crossAlign': 'start',
          'equalSize': false,
        })!,
        [
          _child('a', {'x': 0.9, 'y': 0.9, 'w': 0.2, 'h': 0.5}),
          _child('b', {'x': 0.1, 'y': 0.1, 'w': 0.4}),
        ],
      );
      // Content 0.2 + 0.1 + 0.4 = 0.7, centered from 0.15.
      _expectBox(out['a'], x: 0.25, y: 0.25, w: 0.2, h: 0.5);
      // No stored cross extent: the child falls back to the full box.
      _expectBox(out['b'], x: 0.65, y: 0.5, w: 0.4, h: 1);
    });

    test('space-between spreads the leftover axis', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'row', 'mainAlign': 'spaceBetween', 'equalSize': false})!,
        [
          _child('a', {'x': 0, 'y': 0, 'w': 0.2, 'h': 1}),
          _child('b', {'x': 0, 'y': 0, 'w': 0.2, 'h': 1}),
          _child('c', {'x': 0, 'y': 0, 'w': 0.2, 'h': 1}),
        ],
      );
      expect(out['a']!['x'], _near(0.1));
      expect(out['b']!['x'], _near(0.5));
      expect(out['c']!['x'], _near(0.9));
    });

    test('end alignment packs against the far edge', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({
          'kind': 'row',
          'spacing': 0.1,
          'mainAlign': 'end',
          'crossAlign': 'end',
          'equalSize': false,
        })!,
        [
          _child('a', {'x': 0, 'y': 0, 'w': 0.2, 'h': 0.4}),
        ],
      );
      _expectBox(out['a'], x: 0.9, y: 0.8, w: 0.2, h: 0.4);
    });

    test('an intrinsic child under equal-size off takes the equal share', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'row', 'spacing': 0, 'equalSize': false})!,
        [
          _child('a', {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 1}),
          _child('b'),
        ],
      );
      expect(out['a']!['w'], _near(0.5));
      expect(out['b']!['w'], _near(0.5));
    });

    test('pathological spacing never writes a non-positive extent', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'row', 'spacing': 0.5})!,
        [_child('a'), _child('b'), _child('c')],
      );
      for (final id in ['a', 'b', 'c']) {
        expect(out[id]!['w'], _near(0.01));
      }
    });

    test('rotation and opacity survive the reflow', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.row), [
        _child('a', {'x': 0.1, 'y': 0.1, 'rotation': 45, 'opacity': 0.5}),
      ]);
      expect(out['a']!['rotation'], 45);
      expect(out['a']!['opacity'], 0.5);
      expect(out['a']!.containsKey('anchor'), isFalse);
    });
  });

  group('column', () {
    test('mirrors the row on the vertical axis', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.column), [
        _child('a'),
        _child('b'),
        _child('c'),
      ]);
      const h = (1 - 0.08) / 3;
      _expectBox(out['a'], x: 0.5, y: h / 2, w: 1, h: h);
      _expectBox(out['b'], x: 0.5, y: 0.5, w: 1, h: h);
      _expectBox(out['c'], x: 0.5, y: 1 - h / 2, w: 1, h: h);
    });

    test('equal-size off keeps stored heights and aligns the cross axis', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({
          'kind': 'column',
          'spacing': 0.1,
          'mainAlign': 'start',
          'crossAlign': 'center',
          'equalSize': false,
        })!,
        [
          _child('a', {'x': 0, 'y': 0, 'w': 0.4, 'h': 0.3}),
          _child('b', {'x': 0, 'y': 0, 'w': 0.6, 'h': 0.2}),
        ],
      );
      _expectBox(out['a'], x: 0.5, y: 0.15, w: 0.4, h: 0.3);
      _expectBox(out['b'], x: 0.5, y: 0.5, w: 0.6, h: 0.2);
    });
  });

  group('grid', () {
    test('fills cells left to right, top to bottom', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'grid', 'columns': 2, 'spacing': 0.1})!,
        [_child('a'), _child('b'), _child('c'), _child('d')],
      );
      _expectBox(out['a'], x: 0.225, y: 0.225, w: 0.45, h: 0.45);
      _expectBox(out['b'], x: 0.775, y: 0.225, w: 0.45, h: 0.45);
      _expectBox(out['c'], x: 0.225, y: 0.775, w: 0.45, h: 0.45);
      _expectBox(out['d'], x: 0.775, y: 0.775, w: 0.45, h: 0.45);
    });

    test('a ragged last row keeps the grid cell size', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'grid', 'columns': 2, 'spacing': 0.1})!,
        [_child('a'), _child('b'), _child('c')],
      );
      _expectBox(out['c'], x: 0.225, y: 0.775, w: 0.45, h: 0.45);
    });
  });

  group('list', () {
    test('stacks full-width rows of the item height', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'list', 'itemHeight': 0.2, 'spacing': 0.05})!,
        [_child('a'), _child('b'), _child('c')],
      );
      _expectBox(out['a'], x: 0.5, y: 0.1, w: 1, h: 0.2);
      _expectBox(out['b'], x: 0.5, y: 0.35, w: 1, h: 0.2);
      _expectBox(out['c'], x: 0.5, y: 0.6, w: 1, h: 0.2);
    });
  });

  group('split', () {
    test('two children take the two columns at the ratio', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'split', 'ratio': 0.6, 'gutter': 0.1})!,
        [_child('a'), _child('b')],
      );
      _expectBox(out['a'], x: 0.275, y: 0.5, w: 0.55, h: 1);
      _expectBox(out['b'], x: 0.825, y: 0.5, w: 0.35, h: 1);
    });

    test('extra children flow into the second column as a column', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'split', 'ratio': 0.6, 'gutter': 0.1})!,
        [_child('a'), _child('b'), _child('c')],
      );
      _expectBox(out['a'], x: 0.275, y: 0.5, w: 0.55, h: 1);
      _expectBox(out['b'], x: 0.825, y: 0.225, w: 0.35, h: 0.45);
      _expectBox(out['c'], x: 0.825, y: 0.775, w: 0.35, h: 0.45);
    });

    test('a lone child keeps to the first column', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.split), [_child('a')]);
      _expectBox(out['a'], x: 0.24, y: 0.5, w: 0.48, h: 1);
    });
  });

  group('titleBody', () {
    test('the first child takes the band, the rest stack below', () {
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'titleBody', 'heightFraction': 0.3, 'spacing': 0.05})!,
        [_child('t'), _child('a'), _child('b')],
      );
      _expectBox(out['t'], x: 0.5, y: 0.15, w: 1, h: 0.3);
      _expectBox(out['a'], x: 0.5, y: 0.5, w: 1, h: 0.3);
      _expectBox(out['b'], x: 0.5, y: 0.85, w: 1, h: 0.3);
    });

    test('a lone title fills only the band', () {
      final out = reflowedBlockTransforms(BlockSpec.defaults(BlockKind.titleBody), [_child('t')]);
      _expectBox(out['t'], x: 0.5, y: 0.125, w: 1, h: 0.25);
    });
  });

  group('nesting', () {
    test('a nested block group is one box to the outer reflow', () {
      final inner = _child('inner-group', {'x': 0.2, 'y': 0.2, 'w': 0.3, 'h': 0.3});
      inner['type'] = 'Group';
      inner['children'] = [
        _child('ia', {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 1}),
        _child('ib', {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 1}),
      ];
      final out = reflowedBlockTransforms(
        BlockSpec.fromJson({'kind': 'column', 'spacing': 0})!,
        [inner, _child('b')],
      );
      // The group gets a slot like any child; its own children are untouched.
      _expectBox(out['inner-group'], x: 0.5, y: 0.25, w: 1, h: 0.5);
      expect(out.containsKey('ia'), isFalse);
      expect(out.containsKey('ib'), isFalse);
    });
  });
}
