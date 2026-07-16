import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';

void main() {
  group('CanvasViewportController', () {
    test('fit centers the canvas with a margin and clamps the scale', () {
      final controller = CanvasViewportController()
        ..fit(const Size(320, 180), const Size(800, 600), margin: 40);
      expect(controller.scale, closeTo((800 - 80) / 320, 0.001));
      final canvasCenter = controller.toViewport(const Offset(160, 90));
      expect(canvasCenter.dx, closeTo(400, 0.001));
      expect(canvasCenter.dy, closeTo(300, 0.001));
    });

    test('zoomTo keeps the focal point stable', () {
      final controller = CanvasViewportController()
        ..fit(const Size(320, 180), const Size(800, 600));
      const focal = Offset(200, 150);
      final before = controller.toCanvas(focal);
      controller.zoomTo(2, focalInViewport: focal);
      expect(controller.scale, 2);
      final after = controller.toCanvas(focal);
      expect(after.dx, closeTo(before.dx, 0.001));
      expect(after.dy, closeTo(before.dy, 0.001));
    });

    test('toCanvas and toViewport are inverses', () {
      final controller = CanvasViewportController()
        ..zoomTo(1.7)
        ..panBy(const Offset(33, -12));
      const point = Offset(123, 45);
      final roundTrip = controller.toViewport(controller.toCanvas(point));
      expect(roundTrip.dx, closeTo(point.dx, 0.001));
      expect(roundTrip.dy, closeTo(point.dy, 0.001));
    });

    test('zoomToRect frames the rect', () {
      final controller = CanvasViewportController()
        ..fit(const Size(320, 180), const Size(800, 600))
        ..zoomToRect(const Rect.fromLTWH(80, 45, 160, 90), const Size(800, 600), margin: 0);
      final center = controller.toViewport(const Offset(160, 90));
      expect(center.dx, closeTo(400, 0.001));
      expect(center.dy, closeTo(300, 0.001));
      expect(controller.scale, closeTo(5, 0.001));
    });

    test('the scale clamps to its bounds', () {
      final controller = CanvasViewportController(minScale: 0.5, maxScale: 4)..zoomTo(99);
      expect(controller.scale, 4);
      controller.zoomTo(0.01);
      expect(controller.scale, 0.5);
    });
  });

  group('CanvasViewport widget', () {
    testWidgets('a scroll wheel zooms toward the pointer', (tester) async {
      final controller = CanvasViewportController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CanvasViewport(
            controller: controller,
            canvasSize: const Size(320, 180),
            child: const ColoredBox(color: Color(0xFF223344)),
          ),
        ),
      );
      controller.fit(const Size(320, 180), tester.getSize(find.byType(CanvasViewport)));
      await tester.pump();
      final before = controller.scale;

      final pointer = TestPointer(1, PointerDeviceKind.mouse)
        ..hover(tester.getCenter(find.byType(CanvasViewport)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pump();
      expect(controller.scale, greaterThan(before));
    });

    testWidgets('dragging pans the canvas', (tester) async {
      final controller = CanvasViewportController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CanvasViewport(
            controller: controller,
            canvasSize: const Size(320, 180),
            child: const ColoredBox(color: Color(0xFF223344)),
          ),
        ),
      );
      final before = controller.toViewport(Offset.zero);
      await tester.drag(find.byType(CanvasViewport), const Offset(50, 30));
      await tester.pump();
      final after = controller.toViewport(Offset.zero);
      expect(after.dx, closeTo(before.dx + 50, 0.001));
      expect(after.dy, closeTo(before.dy + 30, 0.001));
    });
  });
}
