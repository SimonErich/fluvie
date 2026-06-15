import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

void main() {
  group('RenderController', () {
    test('starts at frame 0 by default', () {
      final controller = RenderController();
      addTearDown(controller.dispose);
      expect(controller.frame, 0);
      expect(controller.value, 0);
    });

    test('starts at a custom initial frame', () {
      final controller = RenderController(initialFrame: 12);
      addTearDown(controller.dispose);
      expect(controller.frame, 12);
    });

    test('seek moves the frame and notifies exactly once', () {
      final controller = RenderController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller
        ..addListener(() => notifications++)
        ..seek(7);

      expect(controller.frame, 7);
      expect(notifications, 1);
    });

    test('seeking the current frame does not notify', () {
      final controller = RenderController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller
        ..seek(7)
        ..addListener(() => notifications++)
        ..seek(7);

      expect(controller.frame, 7);
      expect(notifications, 0);
    });

    test('advance steps by 1 by default', () {
      final controller = RenderController();
      addTearDown(controller.dispose);

      controller.advance();

      expect(controller.frame, 1);
    });

    test('advance steps by the given amount', () {
      final controller = RenderController(initialFrame: 2);
      addTearDown(controller.dispose);

      controller.advance(3);

      expect(controller.frame, 5);
    });

    test('seeking a negative frame asserts', () {
      final controller = RenderController();
      addTearDown(controller.dispose);
      expect(() => controller.seek(-1), throwsAssertionError);
    });

    test('a removed listener receives no further notifications', () {
      final controller = RenderController();
      addTearDown(controller.dispose);
      var notifications = 0;
      void listener() => notifications++;
      controller
        ..addListener(listener)
        ..seek(1);
      expect(notifications, 1);

      controller
        ..removeListener(listener)
        ..seek(2);

      expect(notifications, 1);
      expect(controller.frame, 2);
    });
  });
}
