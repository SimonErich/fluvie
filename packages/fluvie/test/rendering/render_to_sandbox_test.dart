import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  testWidgets('captures a composition into an in-memory sandbox + manifest', (tester) async {
    tester.view
      ..physicalSize = const Size(64, 64)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF112233)),
        aspect: Aspect.square,
        frameCount: 3,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 64,
      );
    });

    expect(manifest.width, 64);
    expect(manifest.height, 64);
    expect(manifest.frameCount, 3);
    expect(manifest.framesFileName, 'frames.rgba');
    // Video-only on web v1: the plan carries -an, no audio inputs.
    expect(manifest.ffmpegArgs, contains('frames.rgba'));

    final frames = await sandbox.readBytes('frames.rgba');
    expect(frames.length, 3 * 64 * 64 * 4);
    expect(sandbox.names, containsAll(<String>['frames.rgba', 'manifest.json']));
  });

  testWidgets('two renders of the same composition are byte-identical', (tester) async {
    tester.view
      ..physicalSize = const Size(48, 48)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<List<int>> once() async {
      final sandbox = MemoryRenderSandbox();
      await tester.runAsync(() async {
        await renderToSandbox(
          composition: const ColoredBox(color: Color(0xFF204060)),
          aspect: Aspect.square,
          frameCount: 2,
          sandbox: sandbox,
          capture: const RepaintBoundaryCaptureService(),
          pumpWidget: tester.pumpWidget,
          pumpFrame: tester.pump,
          longEdge: 48,
        );
      });
      return sandbox.readBytes('frames.rgba');
    }

    expect(await once(), await once());
  });

  testWidgets('a poster frame plans a poster invocation', (tester) async {
    tester.view
      ..physicalSize = const Size(32, 32)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        frameCount: 2,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 32,
        posterFrame: 1,
      );
    });

    expect(manifest.posterFileName, 'poster.png');
    expect(manifest.posterArgs, isNotNull);
  });
}
