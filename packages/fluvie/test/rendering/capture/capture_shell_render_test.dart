// Epic 14.5 (WI-24, D-CaptureShell): the production scope mount (P13-DOC-01).
// A reactive / Snapshot / Image composition rendered THROUGH buildCaptureShell
// serves band tables, captured stills, and the decoded media cache in capture
// with NO external host. Renders twice -> byte-identical. This closes the
// "scopes only mounted in the example host" deviation.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/bars/bars.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

import '../fakes/fake_media_resolver.dart';

const int _width = 24;
const int _height = 24;

BandTable _rampTable(int frames) {
  final bass = Float64List(frames);
  for (var f = 0; f < frames; f++) {
    bass[f] = frames == 1 ? 1 : f / (frames - 1);
  }
  return BandTable({AudioBand.bass: bass});
}

Future<ui.Image> _solidImage(int color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = ui.Color(color),
  );
  return recorder.endRecording().toImage(4, 4);
}

/// Captures [composition] through the production shell, parameterized by the
/// injected pre-pass results — the exact wiring the CLI and example reuse.
Future<Uint8List> _captureThroughShell(
  WidgetTester tester, {
  required Widget composition,
  required int frameCount,
  MediaResolver? resolver,
  SnapshotCaptureScope? snapshotScope,
  ReactiveTracks reactiveTracks = noReactiveTracks,
}) async {
  tester.view.physicalSize = const ui.Size(_width * 1.0, _height * 1.0);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = RenderController();
  final boundaryKey = GlobalKey();
  final shell = buildCaptureShell(
    composition: composition,
    boundaryKey: boundaryKey,
    controller: controller,
    resolver: resolver,
    snapshotScope: snapshotScope,
    reactiveTracks: reactiveTracks,
  );
  await tester.pumpWidget(shell.tree);

  final dir = Directory.systemTemp.createTempSync('fluvie_shell_render_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final service = RenderService(
    capture: const RepaintBoundaryCaptureService(),
    media: resolver ?? const NoMediaResolver(),
  );
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
        // Reset the MOUNTED scope's cursor (a fresh instance from the shell),
        // not the pre-pass result, so unkeyed Snapshot indices stay stable.
        shell.mountedSnapshotScope?.resetCursor();
        await tester.pump();
      },
      boundaryKey: boundaryKey,
      compositionKey: 'shell-render',
    );
  });
  return File('${dir.path}/frames.rgba').readAsBytesSync();
}

void main() {
  group('render through the production shell (WI-24)', () {
    testWidgets('a reactive composition serves band tables to Bars with no host', (tester) async {
      const song = AudioSource.asset('audio/song.mp3');
      const frames = 6;

      Future<Uint8List> once() async {
        final resolver = FakeMediaResolver(const {}, bandTables: {song: _rampTable(frames)});
        await resolver.preResolveAll(const []);
        return _captureThroughShell(
          tester,
          composition: const Bars(count: 8, gain: 0.8),
          frameCount: frames,
          resolver: resolver,
          reactiveTracks: ReactiveTracks(
            byAnchor: const {},
            defaultSource: song,
            allSources: {song},
          ),
        );
      }

      final first = await once();
      final second = await once();
      expect(first.length, frames * _width * _height * 4);
      // The bars move (the ramp differs frame to frame), proving the table was
      // served — not a neutral, host-less, energy-0 state.
      const frameBytes = _width * _height * 4;
      expect(
        first.sublist(0, frameBytes),
        isNot(orderedEquals(first.sublist((frames - 1) * frameBytes))),
      );
      // Renders twice -> byte-identical.
      expect(first, orderedEquals(second));
    });

    testWidgets('a Snapshot composition reads the captured still through the shell', (
      tester,
    ) async {
      const captureKey = SnapshotCaptureKey.index(0);

      Future<Uint8List> once() async {
        final image = await _solidImage(0xFF2ECC71);
        addTearDown(image.dispose);
        final scope = SnapshotCaptureScope(images: {captureKey: image});
        return _captureThroughShell(
          tester,
          composition: const Snapshot(child: SizedBox(width: 20, height: 20)),
          frameCount: 3,
          snapshotScope: scope,
        );
      }

      final first = await once();
      final second = await once();
      expect(first, orderedEquals(second));
      // The captured green still painted (not a blank frame).
      expect(first.sublist(0, 4), const [0x2E, 0xCC, 0x71, 0xFF]);
    });

    testWidgets('an Image paints from the decoded cache through the shell', (tester) async {
      const source = MediaSource.asset('fixtures/swatch.png');

      Future<Uint8List> once() async {
        final image = await _solidImage(0xFF3498DB);
        addTearDown(image.dispose);
        final resolver = FakeMediaResolver(
          {
            source: (bytes: Uint8List.fromList(const [1, 2, 3]), contentHash: 'h'),
          },
          images: {source: image},
        );
        await resolver.preResolveAll(const [source]);
        return _captureThroughShell(
          tester,
          composition: Image.asset('fixtures/swatch.png'),
          frameCount: 2,
          resolver: resolver,
        );
      }

      final first = await once();
      final second = await once();
      expect(first, orderedEquals(second));
      // The blue swatch painted synchronously from the cache (no async pop-in):
      // the centre pixel of the contained image is the swatch blue, not blank.
      const centre = (_height ~/ 2 * _width + _width ~/ 2) * 4;
      expect(first.sublist(centre, centre + 4), const [0x34, 0x98, 0xDB, 0xFF]);
    });
  });
}
