// WI-25 (decision D18/D3/D4): lesson 05 — the media render integration target.
// Two cache-off runs through the real capture harness are byte-identical, and
// the framed photo is present from frame 0 (no async pop-in). Untagged: an
// offline fake resolver serves the decoded fixture and a solid clip frame, so
// the test needs neither ffmpeg nor the network — determinism is the point, not
// the codec.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'fake_lesson_media.dart';
import 'render_harness.dart';

// VideoSize.square at 30 fps; only the opening is captured — enough to prove
// the photo is on from frame 0 and that two runs match.
const int _width = 1080;
const int _height = 1080;
const int _captured = 8;

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_lesson05_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// The RGBA bytes of pixel ([x], [y]) in [frame] of a raw frames file.
List<int> _pixel(Uint8List frames, {required int frame, required int x, required int y}) {
  final offset = ((frame * _height + y) * _width + x) * 4;
  return frames.sublist(offset, offset + 4);
}

/// An offline resolver for the entry's declared sources (decision D16).
Future<MediaResolver?> _fakeMedia(CompositionEntry entry) async {
  if (entry.mediaSources.isEmpty) return null;
  final resolver = await FakeLessonMedia.create(entry.mediaSources);
  await resolver.preResolveAll(entry.mediaSources);
  return resolver;
}

void main() {
  testWidgets('lesson 05 declares its image and clip for the collect pass', (tester) async {
    final entry = compositionForKey('05_images_and_clips')!;
    expect(entry.mediaSources, hasLength(2), reason: 'one image asset, one clip asset');
  });

  testWidgets('two cache-off runs are byte-identical with equal manifest digests', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outA = _tempDir('a');
    final outB = _tempDir('b');
    final entry = compositionForKey('05_images_and_clips')!;

    final manifestA = await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outA,
      frameCountOverride: _captured,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
      prepareMedia: _fakeMedia,
    );
    final manifestB = await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outB,
      frameCountOverride: _captured,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
      prepareMedia: _fakeMedia,
    );

    expect(manifestA.renderDigest, manifestB.renderDigest);
    expect(manifestA, manifestB);
    expect(
      File('${outA.path}/frames.rgba').readAsBytesSync(),
      File('${outB.path}/frames.rgba').readAsBytesSync(),
    );
  });

  testWidgets('the photo is present from frame 0 — no async pop-in', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outDir = _tempDir('probe');
    final entry = compositionForKey('05_images_and_clips')!;
    await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outDir,
      frameCountOverride: _captured,
      cacheEnabled: false,
      cacheRoot: cacheRoot,
      prepareMedia: _fakeMedia,
    );
    final frames = File('${outDir.path}/frames.rgba').readAsBytesSync();
    expect(frames.length, _captured * _width * _height * 4);

    // The polaroid sits at the canvas centre; the white frame border there is
    // far brighter than the dark ink backdrop. If the image popped in late,
    // frame 0 would still be pure background.
    const x = 540;
    const y = 470;
    final frame0 = _pixel(frames, frame: 0, x: x, y: y);
    final backdrop = _pixel(frames, frame: 0, x: 60, y: 60);
    expect(
      frame0[0],
      greaterThan(backdrop[0] + 80),
      reason: 'the polaroid is already painted at frame 0 (white frame vs ink backdrop)',
    );
  });
}
