import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The Phase 4 stop-gate spike: prove that RepaintBoundary.toImage under the
// headless FlutterTester device produces exact-resolution, byte-deterministic
// RGBA. Zero production-code imports by design. If this file goes red, the
// whole capture architecture changes (decision D16) — escalate, do not patch.

Future<Uint8List> _captureRgba(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = ui.Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('physicalSize 64x64 at DPR 1.0 captures exactly 64x64', (tester) async {
    _setView(tester, 64, 64);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Color(0xFF3366CC)),
      ),
    );

    final bytes = await _captureRgba(tester, key);

    expect(bytes.length, 64 * 64 * 4);
  });

  testWidgets('every pixel of a solid box is the exact color', (tester) async {
    _setView(tester, 64, 64);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Color(0xFF3366CC)),
      ),
    );

    final bytes = await _captureRgba(tester, key);

    for (var i = 0; i < bytes.length; i += 4) {
      expect(bytes[i], 0x33, reason: 'red at pixel ${i ~/ 4}');
      expect(bytes[i + 1], 0x66, reason: 'green at pixel ${i ~/ 4}');
      expect(bytes[i + 2], 0xCC, reason: 'blue at pixel ${i ~/ 4}');
      expect(bytes[i + 3], 0xFF, reason: 'alpha at pixel ${i ~/ 4}');
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

    final first = await _captureRgba(tester, key);
    final second = await _captureRgba(tester, key);

    expect(first, second);
  });

  testWidgets('a non-square 320x240 capture is exact at target resolution', (tester) async {
    _setView(tester, 320, 240);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Color(0xFFFF8800)),
      ),
    );

    final bytes = await _captureRgba(tester, key);

    expect(bytes.length, 320 * 240 * 4);
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0x88);
    expect(bytes[2], 0x00);
  });
}
