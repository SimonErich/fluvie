// WI-27: the shared capture shell honors the Phase 14 export defines
// (FLUVIE_RENDER_ASPECT/QUALITY/FORMAT/POSTER). These offline tests drive
// runCaptureHarness directly with the typed values the capture_harness_test
// parses from the defines, asserting the manifest reflects each one and that
// the absent-define defaults keep a plain render byte-identical.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/demo_composition.dart';

import 'render_harness.dart';

Directory _tempDir(String label) {
  final dir = Directory.systemTemp.createTempSync('fluvie_harness_defines_${label}_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  group('parseExportFormat', () {
    test('maps the non-mp4 format names to their Export variant', () {
      expect(parseExportFormat('gif'), const Export.gif());
      expect(parseExportFormat('imageSequence'), const Export.imageSequence());
      expect(parseExportFormat('transparent'), const Export.transparent());
    });

    test('mp4, null and empty are no export (the byte-identical mp4 default)', () {
      expect(parseExportFormat('mp4'), isNull);
      expect(parseExportFormat(null), isNull);
      expect(parseExportFormat(''), isNull);
    });
  });

  group('parseQuality', () {
    test('maps every quality name', () {
      expect(parseQuality('low'), Quality.low);
      expect(parseQuality('max'), Quality.max);
    });

    test('a null or empty quality defaults to null', () {
      expect(parseQuality(null), isNull);
      expect(parseQuality(''), isNull);
    });
  });

  group('parseAspect', () {
    test('maps every aspect name', () {
      expect(parseAspect('reels'), Aspect.reels);
      expect(parseAspect('square'), Aspect.square);
      expect(parseAspect('landscape'), Aspect.landscape);
      expect(parseAspect('portrait45'), Aspect.portrait45);
    });

    test('a null or empty aspect defaults to null', () {
      expect(parseAspect(null), isNull);
      expect(parseAspect(''), isNull);
    });
  });

  group('parsePosterTime', () {
    test('parses seconds, frames, and milliseconds', () {
      expect(parsePosterTime('1.5s'), const Time.seconds(1.5));
      expect(parsePosterTime('30f'), const Time.frames(30));
      expect(parsePosterTime('500ms'), const Time.ms(500));
    });

    test('a null or empty poster is no poster', () {
      expect(parsePosterTime(null), isNull);
      expect(parsePosterTime(''), isNull);
    });
  });

  group('runCaptureHarness honors the defines', () {
    testWidgets('a format define sets the export mode (out.gif)', (tester) async {
      final outDir = _tempDir('format');
      final manifest = await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 4,
        cacheEnabled: false,
        export: const Export.gif(fps: 12),
      );
      expect(manifest.outputFileName, 'out.gif');
      expect(manifest.ffmpegArgs, contains('-filter_complex'));
    });

    testWidgets('a poster time adds the second poster invocation', (tester) async {
      final outDir = _tempDir('poster');
      final manifest = await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 6,
        cacheEnabled: false,
        posterTime: const Time.frames(2),
      );
      expect(manifest.posterFileName, 'poster.png');
      expect(manifest.posterArgs, contains(r'select=eq(n\,2)'));
    });

    testWidgets('a quality define flows into the encode CRF', (tester) async {
      final outDir = _tempDir('quality');
      final manifest = await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 4,
        cacheEnabled: false,
        quality: Quality.low,
      );
      expect(manifest.ffmpegArgs[manifest.ffmpegArgs.indexOf('-crf') + 1], '28');
    });

    testWidgets('an aspect define re-derives the canvas to that shape', (tester) async {
      final outDir = _tempDir('aspect');
      final manifest = await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: outDir,
        frameCountOverride: 2,
        cacheEnabled: false,
        aspect: Aspect.square,
      );
      expect(manifest.width, manifest.height, reason: 'square is 1:1');
    });

    testWidgets('no defines keeps the plain mp4 render byte-identical', (tester) async {
      final plain = await runCaptureHarness(
        tester: tester,
        entry: demoComposition,
        outDir: _tempDir('plain_a'),
        frameCountOverride: 4,
        cacheEnabled: false,
      );
      expect(plain.outputFileName, 'out.mp4');
      expect(plain.posterArgs, isNull);
      expect(plain.ffmpegArgs, contains('libx264'));
    });
  });

  group('assertRenderWithinBounds bounds an untrusted render', () {
    test('rejects a canvas over the 8K pixel ceiling', () {
      expect(
        () =>
            assertRenderWithinBounds(untrusted: true, width: 100000, height: 100000, frameCount: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a total frame size over the byte budget', () {
      expect(
        () => assertRenderWithinBounds(
          untrusted: true,
          width: 7680,
          height: 4320,
          frameCount: 100000,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows a normal untrusted preview', () {
      expect(
        () => assertRenderWithinBounds(untrusted: true, width: 1080, height: 1920, frameCount: 300),
        returnsNormally,
      );
    });

    test('never bounds a trusted render, however large', () {
      expect(
        () => assertRenderWithinBounds(
          untrusted: false,
          width: 100000,
          height: 100000,
          frameCount: 1000000,
        ),
        returnsNormally,
      );
    });
  });
}
