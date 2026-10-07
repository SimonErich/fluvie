import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/document/anchor_triggers.dart';

Map<String, Object?> _deck(List<Map<String, Object?>> children) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {'duration': '60f', 'children': children},
  ],
};

void main() {
  group('mintedAnchorId', () {
    test('uses the element id itself when free', () {
      final document = EditorDocument.fromJson(
        _deck([
          {'id': 'el-a', 'type': 'Box', 'width': 10, 'height': 10},
        ]),
      );
      expect(mintedAnchorId(document, 'el-a'), 'el-a');
    });

    test('suffixes past declared anchors until the id is free', () {
      final document = EditorDocument.fromJson(
        _deck([
          {'id': 'el-a', 'type': 'Box', 'width': 10, 'height': 10, 'anchor': 'el-b'},
          {'id': 'el-x', 'type': 'Box', 'width': 10, 'height': 10, 'anchor': 'el-b-2'},
          {'id': 'el-b', 'type': 'Box', 'width': 10, 'height': 10},
        ]),
      );
      expect(mintedAnchorId(document, 'el-b'), 'el-b-3');
    });
  });

  test('link palettes are values', () {
    const palette = TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF));
    expect(palette, const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF)));
    expect(
      palette.hashCode,
      const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF)).hashCode,
    );
    expect(
      palette,
      isNot(const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF0000FF))),
    );
  });
}
