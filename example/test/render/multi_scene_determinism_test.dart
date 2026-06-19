// Phase 6 DoD (WI-31): the multi-scene composition renders deterministically
// through the real capture harness — two cache-off runs are byte-identical —
// and the SceneGate boundary is provable at the pixel level: scene 2's
// background appears exactly one frame after scene 1's last frame.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/multi_scene_composition.dart';

import 'render_harness.dart';

const int _width = 320;
const int _height = 240;

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_multi_scene_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// The RGBA bytes of pixel ([x], [y]) in frame [frame] of a raw frames file.
List<int> _pixel(Uint8List frames, {required int frame, required int x, required int y}) {
  final offset = ((frame * _height + y) * _width + x) * 4;
  return frames.sublist(offset, offset + 4);
}

List<int> _rgba(Color color) => [
  (color.r * 255).round(),
  (color.g * 255).round(),
  (color.b * 255).round(),
  (color.a * 255).round(),
];

void main() {
  testWidgets('the registry geometry matches the Video it mounts', (tester) async {
    expect(multiSceneComposition.key, 'multi_scene');
    expect(multiSceneComposition.width, _width);
    expect(multiSceneComposition.height, _height);
    expect(multiSceneComposition.fps, 30);
    expect(multiSceneComposition.frameCount, 84);
    expect(multiSceneVideo().totalFrames, 84);
    expect(multiSceneVideo().sceneStartFrames, [0, 24, 60]);
  });

  testWidgets('two cache-off runs are byte-identical with equal manifest digests', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outA = _tempDir('a');
    final outB = _tempDir('b');

    final manifestA = await runCaptureHarness(
      tester: tester,
      entry: multiSceneComposition,
      outDir: outA,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
    );
    final manifestB = await runCaptureHarness(
      tester: tester,
      entry: multiSceneComposition,
      outDir: outB,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
    );

    expect(manifestA.renderDigest, manifestB.renderDigest);
    expect(manifestA, manifestB);
    expect(
      File('${outA.path}/frames.rgba').readAsBytesSync(),
      File('${outB.path}/frames.rgba').readAsBytesSync(),
    );
  });

  testWidgets('scene 2 paints only after scene 1 ends (pixel-level gating proof)', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outDir = _tempDir('gate');
    await runCaptureHarness(
      tester: tester,
      entry: multiSceneComposition,
      outDir: outDir,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
    );
    final frames = File('${outDir.path}/frames.rgba').readAsBytesSync();
    expect(frames.length, 84 * _width * _height * 4);

    final scene1 = _rgba(multiSceneScene1Color);
    final scene3 = _rgba(multiSceneScene3Color);
    // Scene 1's solid backdrop fills its whole window [0, 24)...
    expect(_pixel(frames, frame: 0, x: 8, y: 8), scene1);
    expect(_pixel(frames, frame: 23, x: 8, y: 8), scene1);
    // ...and is replaced exactly at frame 24 by scene 2's gradient, whose
    // top-left corner is blue-dominant (the unshifted base — the shift is
    // still 6 frames away).
    final boundary = _pixel(frames, frame: 24, x: 8, y: 8);
    expect(boundary, isNot(scene1));
    expect(
      boundary[2],
      greaterThan(boundary[0]),
      reason: 'scene 2 opens on the blue-first gradient, not scene 1 red',
    );
    // The second boundary: scene 3's ink backdrop takes over at frame 60.
    expect(_pixel(frames, frame: 59, x: 8, y: 8), isNot(scene3));
    expect(_pixel(frames, frame: 60, x: 8, y: 8), scene3);
  });
}
