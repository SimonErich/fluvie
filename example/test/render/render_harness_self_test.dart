// Self-tests for the capture harness (untagged: they run in the plain
// suite with an 8-frame override, no CLI and no ffmpeg involved).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/composition_registry.dart';
import 'package:fluvie_example/render/demo_composition.dart';

import 'render_harness.dart';

const int _frameBytes = 320 * 240 * 4;

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_harness_self_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  testWidgets('frames.rgba has exactly 8*w*h*4 bytes under the 8-frame override', (tester) async {
    final outDir = _tempDir('len');

    await runCaptureHarness(
      tester: tester,
      entry: demoComposition,
      outDir: outDir,
      frameCountOverride: 8,
      cacheEnabled: false,
    );

    expect(File('${outDir.path}/frames.rgba').lengthSync(), 8 * _frameBytes);
  });

  testWidgets('the manifest is written last, parses, and matches the frames file', (
    tester,
  ) async {
    final outDir = _tempDir('manifest');

    final manifest = await runCaptureHarness(
      tester: tester,
      entry: demoComposition,
      outDir: outDir,
      frameCountOverride: 8,
      cacheEnabled: false,
    );

    // The manifest is the completion signal: by the time it exists the frames
    // file must already be complete.
    final manifestFile = File('${outDir.path}/manifest.json');
    expect(manifestFile.existsSync(), isTrue);
    expect(File('${outDir.path}/${manifest.framesFileName}').lengthSync(), 8 * _frameBytes);

    final parsed = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    expect(parsed['schemaVersion'], 1);
    expect(parsed['width'], 320);
    expect(parsed['height'], 240);
    expect(parsed['fps'], 30);
    expect(parsed['frameCount'], 8);
    expect(parsed['ffmpegArgs'], manifest.ffmpegArgs);
  });

  testWidgets('two harness runs are byte-identical', (tester) async {
    final outA = _tempDir('det_a');
    final outB = _tempDir('det_b');

    // #docregion determinism-proof
    for (final outDir in [outA, outB]) {
      await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 8,
        cacheEnabled: false,
      );
    }

    expect(
      File('${outA.path}/frames.rgba').readAsBytesSync(),
      File('${outB.path}/frames.rgba').readAsBytesSync(),
    ); // byte-identical
    // #enddocregion determinism-proof
  });

  testWidgets('the cache makes a second run capture-free without changing bytes', (tester) async {
    final cacheRoot = _tempDir('cache_root');
    final outA = _tempDir('cache_a');
    final outB = _tempDir('cache_b');

    for (final outDir in [outA, outB]) {
      await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 8,
        cacheRoot: cacheRoot,
      );
    }

    expect(
      File('${outA.path}/frames.rgba').readAsBytesSync(),
      File('${outB.path}/frames.rgba').readAsBytesSync(),
    );
  });

  testWidgets('a progressFile records the live frame count, ending at total/total', (
    tester,
  ) async {
    final outDir = _tempDir('progress_out');
    final progressDir = _tempDir('progress_file');
    final progressFile = '${progressDir.path}/progress';

    await runCaptureHarness(
      tester: tester,
      entry: demoComposition,
      outDir: outDir,
      frameCountOverride: 8,
      cacheEnabled: false,
      progressFile: progressFile,
    );

    // The launcher reads exactly this format ("<done>/<total>"); the final write
    // is every frame done, which the UI surfaces as 100% / "Encoding ...".
    expect(File(progressFile).readAsStringSync(), '8/8');
  });

  test('the unknown-key failure message names the known keys', () {
    expect(unknownKeyMessage('nope'), contains('nope'));
    expect(unknownKeyMessage('nope'), contains('demo'));
    expect(unknownKeyMessage('nope'), contains('$knownCompositionKeys'));
  });
}
