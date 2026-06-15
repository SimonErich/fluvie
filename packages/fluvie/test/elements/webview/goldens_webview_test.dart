// WI-15 (D-WebHtml/D-Raster/D20): the WebView/Html golden. A browser is needed
// for real HTML pixels (deferred behind the snapshot tag), so the golden's
// raster is drawn IN-PROCESS by a small deterministic "web page" painter (a
// header bar plus stacked text-block rectangles) and carried down by an
// ImageResolverScope keyed by the Html's own snapshotSource — more
// representative than a flat stripe, fully offline and deterministic:
//   * html_render — an Html(...) at a fixed viewport painting that page raster.
@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/webview/html.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

import '../../animation/helpers/golden_frame.dart';
import '../../rendering/fakes/fake_media_resolver.dart';

const _viewport = SnapshotViewport(width: 200, height: 150);
const _canvas = Size(220, 170);
const _html = '<html><body><h1>Fluvie</h1><p>page</p></body></html>';

/// Draws a deterministic, font-free "web page" raster: a tinted page, a header
/// bar, and three stacked text-block rectangles — a recognisable page shape
/// standing in for real browser pixels until the CDP path lands.
Future<ui.Image> _pageRaster(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas
    ..drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = const ui.Color(0xFFF4F6F8))
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, w, h * 0.18),
      ui.Paint()..color = const ui.Color(0xFF2D89EF),
    );
  final block = ui.Paint()..color = const ui.Color(0xFFB0BEC5);
  for (var i = 0; i < 3; i++) {
    final top = h * (0.30 + i * 0.18);
    canvas.drawRect(ui.Rect.fromLTWH(w * 0.08, top, w * 0.84, h * 0.10), block);
  }
  return recorder.endRecording().toImage(width, height);
}

Future<void> main() async {
  final raster = await _pageRaster(_viewport.pixelWidth, _viewport.pixelHeight);
  const page = Html(_html, viewport: _viewport);
  final resolver = FakeMediaResolver(
    {},
    snapshots: {page.snapshotSource!: raster},
  );
  await resolver.preResolveAll(const []);

  Widget scoped(Widget child) => ImageResolverScope(resolver: resolver, child: child);

  await goldenMotionFrames(
    description: 'Html renders a page raster at a fixed viewport',
    fileName: 'html_render',
    frames: const [0],
    size: _canvas,
    subject: () => scoped(
      const Center(
        child: SizedBox(
          width: 200,
          height: 150,
          child: page,
        ),
      ),
    ),
  );
}
