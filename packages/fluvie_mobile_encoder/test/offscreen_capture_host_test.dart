import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie_mobile_encoder/src/offscreen_capture_host.dart';

class _LifetimeProbe extends StatefulWidget {
  const _LifetimeProbe(this.onDispose);
  final VoidCallback onDispose;
  @override
  State<_LifetimeProbe> createState() => _LifetimeState();
}

class _LifetimeState extends State<_LifetimeProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

void main() {
  testWidgets('preparation can replace the mounted tree before frame capture', (tester) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Text('Editor')),
    );
    final surface = OffscreenCaptureHost(const Size(16, 16));
    final prepared = GlobalKey();
    final captured = GlobalKey();
    final pixels = <List<int>>[];
    await tester.runAsync(() async {
      try {
        for (final entry in [
          (prepared, const Color(0xffff0000)),
          (captured, const Color(0xff00ff00)),
        ]) {
          await surface.mount(
            RepaintBoundary(
              key: entry.$1,
              child: ColoredBox(color: entry.$2),
            ),
          );
          final frame = await const RepaintBoundaryCaptureService().capture(
            boundaryKey: entry.$1,
            frameIndex: 0,
            width: 16,
            height: 16,
          );
          pixels.add(frame.rgba.take(4).toList());
        }
        expect(prepared.currentContext, isNull);
      } finally {
        await surface.dispose();
      }
    });
    expect(pixels, [
      [255, 0, 0, 255],
      [0, 255, 0, 255],
    ]);
    expect(captured.currentContext, isNull);
    expect(find.text('Editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offscreen render disposal unmounts state and preserves editor tree', (tester) async {
    var disposed = 0;
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Text('Editor')),
    );
    final surface = OffscreenCaptureHost(const Size(16, 16));
    await tester.runAsync(() async {
      await surface.mount(_LifetimeProbe(() => disposed++));
      await surface.pumpFrame();
      await surface.dispose();
      await surface.dispose();
    });
    expect(disposed, 1);
    expect(find.text('Editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'each queued mobile host captures its resolved first frame without incidental UI pumps',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(textDirection: TextDirection.ltr, child: Text('Editor')),
      );
      for (final size in [32, 24]) {
        final video = VideoSpec.fromJson({
          'fluvieSpec': 1,
          'fps': 30,
          'size': {'width': size, 'height': size},
          'scenes': [
            {
              'duration': '2f',
              'layout': 'canvas',
              'children': [
                {
                  'id': 'red',
                  'type': 'Box',
                  'color': '#FF0000',
                  'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
                  'show': {'from': '0f', 'to': '2f'},
                },
              ],
            },
          ],
        }).build();
        final surface = OffscreenCaptureHost(Size.square(size.toDouble()));
        final controller = RenderController();
        final boundary = GlobalKey();
        final shell = buildCaptureShell(
          composition: video,
          boundaryKey: boundary,
          controller: controller,
        );
        await tester.runAsync(() async {
          await surface.mount(shell.tree);
          controller.seek(0);
          await surface.pumpFrame();
          final first = await const RepaintBoundaryCaptureService().capture(
            boundaryKey: boundary,
            frameIndex: 0,
            width: size,
            height: size,
          );
          try {
            expect(first.rgba.take(4), [255, 0, 0, 255]);
          } finally {
            await surface.dispose();
            controller.dispose();
          }
        });
      }
      expect(find.text('Editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
