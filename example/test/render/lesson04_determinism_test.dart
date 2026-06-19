// WI-21 (Phase 7 DoD, decision D13): lesson 04 — the transition render
// integration target — renders deterministically through the real capture
// harness, and the overlap is provable at the pixel level. The crossFade is
// the video default on a 3-scene Video; the first boundary overlaps, so the
// incoming scene's content is on screen before the outgoing scene's frames
// run out, and the total shortens by the transition window.
//
// Only the first 96 frames are captured: that covers the entire first blend
// window [75, 90) and a pure frame of each adjacent scene, which is all the
// pixel proofs need. The full overlap-shortened frame count is an integer
// property of the layout math, asserted directly off the Video.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/lessons/04_scenes_and_transitions.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'render_harness.dart';

// VideoSize.square at 30 fps; the first boundary crossFade is 15 frames.
const int _width = 1080;
const int _height = 1080;
const int _captured = 96;

// Scene starts [0, 75, 165]; the first blend window is [75, 90).
const int _pureScene1 = 74; // last frame scene 1 owns alone
const int _blendMid = 82; // p == 0.5 across the crossFade
const int _pureScene2 = 90; // first frame scene 2 owns alone

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_lesson04_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// The RGBA bytes of pixel ([x], [y]) in frame [frame] of a raw frames file.
List<int> _pixel(Uint8List frames, {required int frame, required int x, required int y}) {
  final offset = ((frame * _height + y) * _width + x) * 4;
  return frames.sublist(offset, offset + 4);
}

void main() {
  testWidgets('the layout shortens the total by the overlapping crossFade', (tester) async {
    final video = lesson04Video();
    // 3 x 90 frames = 270; the overlapping crossFade (15) shortens it to 255;
    // the sequential wipe leaves it alone.
    expect(video.totalFrames, 255);
    expect(video.sceneStartFrames, [0, 75, 165]);
    expect(compositionForKey('04_scenes_and_transitions')!.frameCount, video.totalFrames);
  });

  testWidgets('two cache-off runs are byte-identical with equal manifest digests', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outA = _tempDir('a');
    final outB = _tempDir('b');
    final entry = compositionForKey('04_scenes_and_transitions')!;

    final manifestA = await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outA,
      frameCountOverride: _captured,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
    );
    final manifestB = await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outB,
      frameCountOverride: _captured,
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

  testWidgets('the crossFade window blends, and overlap puts scene 2 on early', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outDir = _tempDir('blend');
    final entry = compositionForKey('04_scenes_and_transitions')!;
    await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outDir,
      frameCountOverride: _captured,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
    );
    final frames = File('${outDir.path}/frames.rgba').readAsBytesSync();
    expect(frames.length, _captured * _width * _height * 4);

    // A bottom-right background point: scene 1's gradient is pink there (red
    // channel high), scene 2's ink backdrop is dark — and no element reaches
    // the corner, so the difference is pure background.
    const x = 1060;
    const y = 1060;
    final scene1 = _pixel(frames, frame: _pureScene1, x: x, y: y);
    final scene2 = _pixel(frames, frame: _pureScene2, x: x, y: y);
    final blend = _pixel(frames, frame: _blendMid, x: x, y: y);

    // The two pure scenes really differ (gradient pink vs ink).
    expect(scene1[0], greaterThan(scene2[0] + 40), reason: 'scene 1 is pink, scene 2 is ink');
    // The mid-crossFade frame is neither pure scene: it sits between them.
    expect(blend, isNot(equals(scene1)));
    expect(blend, isNot(equals(scene2)));
    expect(blend[0], lessThan(scene1[0]), reason: 'the blend has dimmed toward ink');
    expect(blend[0], greaterThan(scene2[0]), reason: 'the blend still carries the gradient');

    // Overlap: scene 2's content is already present at the window start (75),
    // one frame after scene 1's last solo frame (74). The boundary pixel moves
    // off the pure scene 1 value because scene 2 has begun fading in early.
    final lastSolo = _pixel(frames, frame: 74, x: x, y: y);
    final firstBlend = _pixel(frames, frame: 75, x: x, y: y);
    expect(firstBlend, isNot(equals(lastSolo)), reason: 'scene 2 is on before scene 1 runs out');
  });
}
