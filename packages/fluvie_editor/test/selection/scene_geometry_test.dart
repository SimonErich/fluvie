import 'package:flutter/widgets.dart';
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
          'id': 'el-under',
          'type': 'Box',
          'color': '#111111',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        },
        {
          'id': 'el-over',
          'type': 'Box',
          'color': '#222222',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.25, 'h': 0.25},
        },
        {
          'id': 'el-rotated',
          'type': 'Box',
          'color': '#333333',
          'transform': {'x': 0.85, 'y': 0.2, 'w': 0.2, 'h': 0.05, 'rotation': 45},
        },
        {'id': 'el-intrinsic', 'type': 'Text', 'text': 'hi'},
      ],
    },
  ],
};

SceneGeometry _geometry({Map<String, Size> intrinsic = const {}}) => SceneGeometry.of(
  EditorDocument.fromJson(_deck()),
  0,
  intrinsicSizes: intrinsic,
);

void main() {
  const canvas = Size(320, 180);

  group('geometry resolution', () {
    test('sized transforms resolve through the one Placement mapping', () {
      final geometry = _geometry();
      final under = geometry.rectOf('el-under')!;
      expect(under, const Rect.fromLTWH(80, 45, 160, 90));
      expect(geometry.rotationOf('el-under'), 0);
    });

    test('an intrinsic element without a reported size has no rect yet', () {
      final geometry = _geometry();
      expect(geometry.rectOf('el-intrinsic'), isNull);
    });

    test('a reported size gives an intrinsic element its centered rect', () {
      final geometry = _geometry(intrinsic: {'el-intrinsic': const Size(40, 20)});
      // No transform: the scene stacks it centered on the canvas.
      expect(geometry.rectOf('el-intrinsic'), const Rect.fromLTWH(140, 80, 40, 20));
    });
  });

  group('point hit-testing', () {
    test('hits the topmost element in z-order', () {
      final geometry = _geometry();
      expect(geometry.hitTest(canvas.center(Offset.zero)), 'el-over');
    });

    test('falls through to lower elements outside the top one', () {
      final geometry = _geometry();
      expect(geometry.hitTest(const Offset(100, 60)), 'el-under');
    });

    test('misses empty canvas', () {
      final geometry = _geometry();
      expect(geometry.hitTest(const Offset(5, 170)), isNull);
    });

    test('rotation-aware: hits inside the rotated shape, not its AABB', () {
      final geometry = _geometry();
      final center = geometry.rectOf('el-rotated')!.center;
      expect(geometry.hitTest(center), 'el-rotated');
      // A corner of the unrotated AABB is outside the 45-degree shape.
      final corner = geometry.rectOf('el-rotated')!.topLeft + const Offset(1, 1);
      expect(geometry.hitTest(corner), isNot('el-rotated'));
    });
  });

  group('marquee', () {
    test('collects every element whose shape intersects the rect', () {
      final geometry = _geometry();
      expect(
        geometry.hitTestMarquee(const Rect.fromLTWH(0, 0, 320, 180)),
        {'el-under', 'el-over', 'el-rotated'},
      );
      expect(
        geometry.hitTestMarquee(const Rect.fromLTWH(81, 46, 10, 10)),
        {'el-under'},
      );
      expect(geometry.hitTestMarquee(const Rect.fromLTWH(0, 160, 10, 10)), isEmpty);
    });

    test('a marquee touching only the rotated AABB corner misses the shape', () {
      final geometry = _geometry();
      final aabb = geometry.rectOf('el-rotated')!;
      final cornerProbe = Rect.fromLTWH(aabb.left, aabb.top, 2, 2);
      expect(geometry.hitTestMarquee(cornerProbe), isEmpty);
    });
  });
}
