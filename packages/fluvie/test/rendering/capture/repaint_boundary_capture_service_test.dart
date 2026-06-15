import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:riverpod/riverpod.dart';

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = ui.Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<RawFrame> _capture(
  WidgetTester tester,
  GlobalKey key, {
  int frameIndex = 0,
  int width = 64,
  int height = 64,
}) async {
  const service = RepaintBoundaryCaptureService();
  late final RawFrame frame;
  await tester.runAsync(() async {
    frame = await service.capture(
      boundaryKey: key,
      frameIndex: frameIndex,
      width: width,
      height: height,
    );
  });
  return frame;
}

/// Paints a solid color derived from the current frame with integer math only.
class _FrameColorBox extends StatelessWidget {
  const _FrameColorBox();

  @override
  Widget build(BuildContext context) {
    final f = FrameProvider.of(context).frame;
    return ColoredBox(
      color: Color.fromARGB(255, (f * 5) % 256, (f * 3) % 256, (f * 7) % 256),
    );
  }
}

void main() {
  group('RepaintBoundaryCaptureService', () {
    testWidgets('captures a solid box at exact dimensions and color', (tester) async {
      _setView(tester, 64, 64);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const ColoredBox(color: Color(0xFF3366CC)),
        ),
      );

      final frame = await _capture(tester, key, frameIndex: 5);

      expect(frame.frameIndex, 5);
      expect(frame.width, 64);
      expect(frame.height, 64);
      expect(frame.rgba.length, 64 * 64 * 4);
      for (var i = 0; i < frame.rgba.length; i += 4) {
        expect(frame.rgba[i], 0x33, reason: 'red at pixel ${i ~/ 4}');
        expect(frame.rgba[i + 1], 0x66, reason: 'green at pixel ${i ~/ 4}');
        expect(frame.rgba[i + 2], 0xCC, reason: 'blue at pixel ${i ~/ 4}');
        expect(frame.rgba[i + 3], 0xFF, reason: 'alpha at pixel ${i ~/ 4}');
      }
    });

    testWidgets('two captures of the same pumped frame are byte-identical', (tester) async {
      _setView(tester, 64, 64);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const ColoredBox(color: Color(0xFF3366CC)),
        ),
      );

      final first = await _capture(tester, key);
      final second = await _capture(tester, key);

      expect(first.rgba, second.rgba);
      expect(first, second);
    });

    testWidgets('a boundary key that is not mounted throws a FluvieRenderException', (
      tester,
    ) async {
      _setView(tester, 64, 64);
      final unmounted = GlobalKey();
      await tester.pumpWidget(const SizedBox());

      const service = RepaintBoundaryCaptureService();
      await tester.runAsync(() async {
        await expectLater(
          () => service.capture(boundaryKey: unmounted, frameIndex: 0, width: 64, height: 64),
          throwsA(
            isA<FluvieRenderException>().having(
              (e) => e.message,
              'message',
              contains('not mounted'),
            ),
          ),
        );
      });
    });

    testWidgets('a key on a non-RepaintBoundary render object throws a FluvieRenderException', (
      tester,
    ) async {
      _setView(tester, 64, 64);
      final key = GlobalKey();
      await tester.pumpWidget(SizedBox(key: key));

      const service = RepaintBoundaryCaptureService();
      await tester.runAsync(() async {
        await expectLater(
          () => service.capture(boundaryKey: key, frameIndex: 0, width: 64, height: 64),
          throwsA(
            isA<FluvieRenderException>().having(
              (e) => e.message,
              'message',
              contains('RenderRepaintBoundary'),
            ),
          ),
        );
      });
    });

    testWidgets('a dimension mismatch throws naming expected and actual sizes', (tester) async {
      _setView(tester, 64, 64);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const ColoredBox(color: Color(0xFF3366CC)),
        ),
      );

      const service = RepaintBoundaryCaptureService();
      await tester.runAsync(() async {
        await expectLater(
          () => service.capture(boundaryKey: key, frameIndex: 0, width: 320, height: 240),
          throwsA(
            isA<FluvieRenderException>()
                .having((e) => e.message, 'message', contains('320x240'))
                .having((e) => e.message, 'message', contains('64x64')),
          ),
        );
      });
    });

    testWidgets(
      'frame-dependent color: different frames differ, the same frame is byte-identical',
      (tester) async {
        _setView(tester, 64, 64);
        final key = GlobalKey();
        final controller = RenderController();
        await tester.pumpWidget(
          RenderControllerScope(
            controller: controller,
            child: RepaintBoundary(key: key, child: const _FrameColorBox()),
          ),
        );

        final atFrame0 = await _capture(tester, key);

        controller.seek(10);
        await tester.pump();
        final atFrame10 = await _capture(tester, key, frameIndex: 10);

        controller.seek(0);
        await tester.pump();
        controller.seek(10);
        await tester.pump();
        final atFrame10Again = await _capture(tester, key, frameIndex: 10);

        expect(atFrame0.rgba, isNot(equals(atFrame10.rgba)));
        expect(atFrame10.rgba, atFrame10Again.rgba);
      },
    );
  });

  group('frameCaptureServiceProvider', () {
    test('resolves to RepaintBoundaryCaptureService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(frameCaptureServiceProvider);
      expect(service, isA<RepaintBoundaryCaptureService>());
    });
  });
}
