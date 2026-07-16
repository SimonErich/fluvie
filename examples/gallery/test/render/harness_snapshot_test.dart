// The example's offline snapshot backend (decision D-Lesson): a Mermaid/Html
// composition must rasterize before frame 0 with no Chromium and no network, so
// paint reads a decoded still synchronously.
//
// `renderVideo` owns the snapshot pre-pass, so the proof is a real render: the
// fake goes in through `renderVideo(snapshotService:)` (what runCaptureHarness
// passes), and the resolver the pre-pass filled is read back afterwards through
// the harness's own prepareMedia seam.
//
// Mermaid/WebView/Html are @experimental for 1.0 (their live headless-Chrome
// transport ships disabled). This suite drives the offline fake snapshot
// service, so the experimental-use warning is expected and silenced here.
// ignore_for_file: experimental_member_use

import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie_example/render/composition_entry.dart';

import 'harness_media.dart';
import 'render_harness.dart';

const int _size = 32;
const int _frames = 2;

/// A composition whose one scene paints [child] on a small square canvas.
Video _videoWith(Widget child) => Video(
  width: _size,
  height: _size,
  scenes: [
    Scene(
      duration: const Time.frames(_frames),
      children: [Positioned.fill(child: child)],
    ),
  ],
);

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_harness_snapshot_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Renders [child]'s composition through the harness and returns the resolver
/// the snapshot pre-pass resolved onto, or `null` when it built none.
Future<MediaResolver?> _renderAndCaptureResolver(
  WidgetTester tester,
  Widget child,
  String label,
) async {
  MediaResolver? captured;
  await runCaptureHarness(
    tester: tester,
    entry: CompositionEntry(key: 'snapshot_$label', video: () => _videoWith(child)),
    outDir: _tempDir(label),
    cacheEnabled: false,
    prepareMedia: (video) async => captured = await prepareEntryMedia(video),
  );
  return captured;
}

void main() {
  group('the offline snapshot pre-pass', () {
    testWidgets('builds no resolver for a snapshot-less composition', (tester) async {
      final resolver = await _renderAndCaptureResolver(
        tester,
        const ColoredBox(color: Color(0xFF101010)),
        'none',
      );
      expect(resolver, isNull);
    });

    testWidgets('pre-resolves declared snapshots so paint reads them synchronously', (
      tester,
    ) async {
      const source = SnapshotSource.mermaid('graph TD; A-->B');
      final resolver = await _renderAndCaptureResolver(
        tester,
        const Mermaid('graph TD; A-->B'),
        'mermaid',
      );

      expect(resolver, isA<MediaResolver>());
      // A decoded image is available synchronously after the pre-pass; the render
      // above already leaned on it, because paint has no way to await one.
      expect(resolver!.decodedSnapshotFor(source).width, greaterThan(0));
    });

    testWidgets('is offline-deterministic: the fixture raster needs no browser', (tester) async {
      const viewport = SnapshotViewport(width: 64, height: 48);
      const source = SnapshotSource.html('<p>hi</p>', viewport: viewport);
      final resolver = await _renderAndCaptureResolver(
        tester,
        const Html('<p>hi</p>', viewport: viewport),
        'html',
      );
      expect(resolver!.decodedSnapshotFor(source).height, greaterThan(0));
    });
  });
}
