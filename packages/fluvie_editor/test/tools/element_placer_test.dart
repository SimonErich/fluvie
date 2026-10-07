import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _canvas = Size(320, 180);

void main() {
  group('click placement', () {
    test('the text tool drops a text element at the point', () {
      final json = placeElementAt(
        const ToolState(tool: EditorTool.text),
        const Offset(80, 90),
        _canvas,
      )!;
      expect(json['type'], 'Text');
      final transform = json['transform']! as Map<String, Object?>;
      expect(transform['x'], closeTo(0.25, 1e-9));
      expect(transform['y'], closeTo(0.5, 1e-9));
    });

    test('a shape click places a default-sized shape around the point', () {
      final json = placeElementAt(
        const ToolState(tool: EditorTool.shape),
        const Offset(160, 90),
        _canvas,
      )!;
      expect(json['type'], 'Shape');
      expect(json['kind'], 'rect');
      final rect = json['rect']! as Map<String, Object?>;
      expect((rect['x']! as num) + (rect['w']! as num) / 2, closeTo(160, 1e-9));
      expect((rect['y']! as num) + (rect['h']! as num) / 2, closeTo(90, 1e-9));
    });

    test('select and hand place nothing', () {
      expect(placeElementAt(const ToolState.select(), Offset.zero, _canvas), isNull);
      expect(
        placeElementAt(const ToolState(tool: EditorTool.hand), Offset.zero, _canvas),
        isNull,
      );
    });
  });

  group('drag placement', () {
    test('a rectangle drag becomes a Shape rect over the dragged bounds', () {
      final json = placeElementIn(
        const ToolState(tool: EditorTool.shape),
        const Rect.fromLTWH(40, 30, 120, 60),
        _canvas,
      )!;
      expect(json['kind'], 'rect');
      expect(json['rect'], {'x': 40.0, 'y': 30.0, 'w': 120.0, 'h': 60.0});
    });

    test('an ellipse drag maps to a circle in the dragged bounds', () {
      final json = placeElementIn(
        const ToolState(tool: EditorTool.shape, shape: ShapeVariant.ellipse),
        const Rect.fromLTWH(100, 40, 80, 80),
        _canvas,
      )!;
      expect(json['kind'], 'circle');
      expect(json['center'], {'x': 140.0, 'y': 80.0});
      expect(json['radius'], 40.0);
    });

    test('line and arrow drags carry their endpoints', () {
      final line = placeElementIn(
        const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line),
        Rect.fromPoints(const Offset(20, 30), const Offset(120, 90)),
        _canvas,
        from: const Offset(20, 30),
        to: const Offset(120, 90),
      )!;
      expect(line['kind'], 'line');
      expect(line['from'], {'x': 20.0, 'y': 30.0});
      expect(line['to'], {'x': 120.0, 'y': 90.0});

      final arrow = placeElementIn(
        const ToolState(tool: EditorTool.shape, shape: ShapeVariant.arrow),
        Rect.fromPoints(const Offset(120, 90), const Offset(20, 30)),
        _canvas,
        from: const Offset(120, 90),
        to: const Offset(20, 30),
      )!;
      expect(arrow['type'], 'Arrow');
      expect(arrow['from'], {'x': 120.0, 'y': 90.0});
      expect(arrow['to'], {'x': 20.0, 'y': 30.0});
    });

    test('a text drag sizes the text box as a transform', () {
      final json = placeElementIn(
        const ToolState(tool: EditorTool.text),
        const Rect.fromLTWH(32, 36, 160, 72),
        _canvas,
      )!;
      expect(json['type'], 'Text');
      final transform = json['transform']! as Map<String, Object?>;
      expect(transform['w'], closeTo(0.5, 1e-9));
      expect(transform['h'], closeTo(0.4, 1e-9));
      expect(transform['x'], closeTo((32 + 80) / 320, 1e-9));
    });
  });

  group('media placement', () {
    test('an image source lands as an Image with a drag-sized transform', () {
      final json = placeMediaIn(
        const {'kind': 'file', 'value': '/tmp/photo.png'},
        isVideo: false,
        const Rect.fromLTWH(0, 0, 160, 90),
        _canvas,
      );
      expect(json['type'], 'Image');
      expect(json['source'], {'kind': 'file', 'value': '/tmp/photo.png'});
      final transform = json['transform']! as Map<String, Object?>;
      expect(transform['w'], closeTo(0.5, 1e-9));
    });

    test('a video source lands as a Clip', () {
      final json = placeMediaIn(
        const {'kind': 'file', 'value': '/tmp/broll.mp4'},
        isVideo: true,
        const Rect.fromLTWH(0, 0, 160, 90),
        _canvas,
      );
      expect(json['type'], 'Clip');
      expect(json['fit'], 'cover');
    });
  });
  constrainSuite();
}

// Shift constraints are pure math the canvas applies mid-drag.
void constrainSuite() {
  test('Shift squares rectangles and ellipses toward the longer edge', () {
    expect(
      constrainedEnd(ShapeVariant.rectangle, Offset.zero, const Offset(100, 40)),
      const Offset(100, 100),
    );
    expect(
      constrainedEnd(ShapeVariant.ellipse, const Offset(10, 10), const Offset(-30, 90)),
      const Offset(-70, 90),
    );
  });

  test('Shift snaps lines and arrows to 45-degree steps', () {
    final line = constrainedEnd(ShapeVariant.line, Offset.zero, const Offset(100, 8));
    expect(line.dy, closeTo(0, 1e-9));
    expect(line.dx, closeTo(100.32, 0.01));
    final diagonal = constrainedEnd(ShapeVariant.arrow, Offset.zero, const Offset(90, 100));
    expect(diagonal.dx, closeTo(diagonal.dy, 1e-9));
  });
}
