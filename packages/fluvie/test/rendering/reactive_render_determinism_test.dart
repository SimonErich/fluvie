import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/elements/bars/bars.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

const int _width = 24;
const int _height = 24;

/// A fixture band table whose bass ramps across the render so each frame paints
/// a distinct, deterministic bar height.
BandTable _table(int frames) {
  final bass = Float64List(frames);
  for (var f = 0; f < frames; f++) {
    bass[f] = f / (frames - 1);
  }
  return BandTable({AudioBand.bass: bass});
}

Future<Uint8List> _captureBars(WidgetTester tester, int frameCount) async {
  tester.view.physicalSize = const ui.Size(_width * 1.0, _height * 1.0);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = RenderController();
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RenderModeContext(
      mode: RenderMode.capture,
      child: ReactiveScope(
        table: _table(frameCount),
        child: RenderControllerScope(
          controller: controller,
          child: RepaintBoundary(
            key: boundaryKey,
            child: const Bars(count: 8, gain: 0.8),
          ),
        ),
      ),
    ),
  );

  final dir = Directory.systemTemp.createTempSync('fluvie_reactive_det_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final service = RenderService(capture: const RepaintBoundaryCaptureService());
  await tester.runAsync(() async {
    await service.captureToDirectory(
      config: RenderConfig(
        width: _width,
        height: _height,
        frameCount: frameCount,
        cacheEnabled: false,
      ),
      outDir: dir,
      pump: (frame) async {
        controller.seek(frame);
        await tester.pump();
      },
      boundaryKey: boundaryKey,
      compositionKey: 'reactive-bars',
    );
  });
  return File('${dir.path}/frames.rgba').readAsBytesSync();
}

void main() {
  testWidgets('DETERMINISM: reactive Bars render twice to byte-identical frames', (tester) async {
    const frameCount = 6;
    final first = await _captureBars(tester, frameCount);
    final second = await _captureBars(tester, frameCount);
    expect(first.length, frameCount * _width * _height * 4);
    expect(first, orderedEquals(second));
  });

  testWidgets('the reactive frames are not all identical (the bars actually move)', (tester) async {
    const frameCount = 6;
    final bytes = await _captureBars(tester, frameCount);
    const frameBytes = _width * _height * 4;
    final frame0 = bytes.sublist(0, frameBytes);
    final frameLast = bytes.sublist((frameCount - 1) * frameBytes, frameCount * frameBytes);
    expect(frame0, isNot(orderedEquals(frameLast)));
  });
}
