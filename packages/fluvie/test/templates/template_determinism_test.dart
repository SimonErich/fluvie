// Epic 14.3 (WI-12, acceptance §14.3.3): THE TEMPLATE BYTE-IDENTICAL
// DETERMINISM TEST — the data-driven-batch determinism proof.
//
// A data list of StatHighlightProps is rendered through renderTemplate, and the
// captured frames are compared:
//   - the SAME Props rendered twice yield byte-identical frames (cacheable);
//   - DIFFERENT Props yield different frames (the data really drives the video).
//
// Rendered offline through the production capture shell + RenderService (no
// ffmpeg, the in-process path), so it runs in the plain gate. Each row uses a
// distinct value/label/accent so its frames are distinguishable, and each value
// is small enough that the Counter resolves a stable formatted string at the
// captured frames (the frame is the only clock — §22).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/render_template.dart';
import 'package:fluvie/src/templates/builtin/stat_highlight.dart';

/// The data-driven batch: three distinct stat rows (the §23 "for u in users"
/// pattern), each producing its own video from one template definition.
const _rows = <StatHighlightProps>[
  StatHighlightProps(value: 120, label: 'one', accent: Color(0xFFFF0000)),
  StatHighlightProps(value: 340, label: 'two', accent: Color(0xFF00FF00)),
  StatHighlightProps(value: 999, label: 'three', accent: Color(0xFF0000FF)),
];

/// Renders [props] through renderTemplate over the offline shell and returns the
/// raw captured frame bytes for the reels canvas (longEdge 960 -> 540x960 — big
/// enough for the built-in's headline/label to lay out without overflow).
Future<Uint8List> _frames(WidgetTester tester, StatHighlightProps props) async {
  const aspect = Aspect.reels;
  const longEdge = 960;
  final size = aspect.sizeFor(longEdge);
  tester.view.physicalSize = ui.Size(size.width.toDouble(), size.height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dir = Directory.systemTemp.createTempSync('fluvie_template_determinism_');
  addTearDown(() => dir.deleteSync(recursive: true));

  await tester.runAsync(() async {
    await renderTemplate(
      const StatHighlight(),
      props: props,
      // aspect defaults to the canonical reels (the same `aspect` local below).
      longEdge: longEdge,
      frameCount: 3,
      outDir: dir,
      service: RenderService(capture: const RepaintBoundaryCaptureService()),
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
    );
  });
  return File('${dir.path}/frames.rgba').readAsBytesSync();
}

void main() {
  group('template byte-identical determinism (§14.3.3)', () {
    testWidgets('the same Props render byte-identical frames', (tester) async {
      for (final props in _rows) {
        final first = await _frames(tester, props);
        final second = await _frames(tester, props);
        expect(
          first,
          orderedEquals(second),
          reason: 'rendering ${props.label} twice must be byte-identical',
        );
      }
    });

    testWidgets('different Props render different frames', (tester) async {
      final batch = <Uint8List>[];
      for (final props in _rows) {
        batch.add(await _frames(tester, props));
      }
      // Every pair of distinct rows differs somewhere in its captured frames.
      for (var i = 0; i < batch.length; i++) {
        for (var j = i + 1; j < batch.length; j++) {
          expect(
            _bytesEqual(batch[i], batch[j]),
            isFalse,
            reason: 'rows ${_rows[i].label} and ${_rows[j].label} must differ',
          );
        }
      }
    });

    testWidgets('the whole reels frame buffer is captured', (tester) async {
      final frames = await _frames(tester, _rows.first);
      final size = Aspect.reels.sizeFor(960);
      expect(frames.length, 3 * size.width * size.height * 4);
    });
  });
}

/// Whether [a] and [b] are byte-for-byte equal.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
