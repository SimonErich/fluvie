// WI-24 (decision D-Lesson / D-Reactive): lesson 10 — the audio + captions
// render integration target. The reactive pre-pass decodes the committed WAV
// with the in-house reader and runs the real spectral beat/band DSP before
// frame 0, the SRT is parsed, and the frame loop only reads those immutable
// tables. Two cache-off runs through the real capture harness are byte-identical
// (the determinism proof the lesson leans on), and the bars react to the bass at
// a beat frame.
//
// Untagged and offline: lesson 10 declares no Image/Clip media, so the
// ffmpeg-backed probe/extractor are never reached, and the WAV decoder needs no
// ffmpeg. A full audio-MIXED mp4 (the encoder amix) needs ffmpeg, so it is left
// to the ffmpeg-tagged encode path; the poster golden and this determinism run
// are the offline gate artifacts.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'render_harness.dart';

// VideoSize.hd at 30 fps; the bass loop kicks every 15 frames, so capturing the
// opening is enough to span a beat and prove two runs match.
const int _width = 1920;
const int _height = 1080;
const int _captured = 16;

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_lesson10_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// The RGBA bytes of pixel ([x], [y]) in [frame] of a raw frames file.
List<int> _pixel(Uint8List frames, {required int frame, required int x, required int y}) {
  final offset = ((frame * _height + y) * _width + x) * 4;
  return frames.sublist(offset, offset + 4);
}

void main() {
  testWidgets('lesson 10 declares no Image/Clip media (the WAV is audio)', (tester) async {
    final entry = compositionForKey('10_audio_and_captions')!;
    expect(entry.mediaSources, isEmpty, reason: 'the WAV is an AudioSource, not a MediaSource');
  });

  testWidgets('two cache-off reactive runs are byte-identical (offline, no ffmpeg)', (
    tester,
  ) async {
    final cacheRoot = _tempDir('cache');
    final outA = _tempDir('a');
    final outB = _tempDir('b');
    final entry = compositionForKey('10_audio_and_captions')!;

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

  testWidgets('the bars react to the bass: a beat frame paints over the backdrop', (tester) async {
    final cacheRoot = _tempDir('cache');
    final outDir = _tempDir('probe');
    final entry = compositionForKey('10_audio_and_captions')!;
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

    // The bars rise from the baseline at y = 1080 - 140 = 940 (the bottom of the
    // Positioned band) up by their bass energy, so a probe just above the
    // baseline, inside a bar column, sits in indigo bar fill at a bass beat
    // (frame 0 is a kick onset, energy near peak). The indigo bar (0xFF6C5CE7)
    // has a far higher blue channel there than the dark backdrop corner.
    const x = 985; // inside bar 16 of 32 (slot 54 px wide, bar 40 px, from 967)
    const y = 935; // just above the y = 940 baseline, inside every painted bar
    final onBeat = _pixel(frames, frame: 0, x: x, y: y);
    final backdrop = _pixel(frames, frame: 0, x: 30, y: 30);
    expect(
      onBeat[2],
      greaterThan(backdrop[2] + 60),
      reason: 'an indigo bar (driven by real bass energy) is painted at a beat frame',
    );
  });
}
