import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'harness_audio.dart';
import 'harness_media.dart';
import 'harness_snapshot.dart';

/// The failure message the harness raises for an unregistered key, naming
/// every known key (asserted by the harness self-test).
String unknownKeyMessage(String key) =>
    'Unknown composition key "$key". Known keys: $knownCompositionKeys';

/// Mounts [entry] in capture mode and renders it into [outDir]
/// (`frames.rgba` + `manifest.json`, manifest written last).
///
/// The render itself is fluvie's `renderVideo`; this adapter supplies the
/// `flutter_test` mechanics (the pump, the view, a real event loop) and the
/// example's offline fakes, so the gallery renders with no ffmpeg, no Chromium,
/// and no network. The CLI's generated harness calls the same function with the
/// platform's real resolver, which is what keeps the two from drifting.
///
/// Reports `fluvie-capture: cache hits <n> of <total>` on stdout so the CLI's
/// `--verbose` mode can surface cache behavior. [cacheRoot] overrides the shared
/// cache directory (self-tests pass a temp root; the CLI path uses the default,
/// which is what makes second runs hit).
Future<RenderManifest> runCaptureHarness({
  required WidgetTester tester,
  required CompositionEntry entry,
  required Directory outDir,
  int? frameCountOverride,
  bool cacheEnabled = true,
  Directory? cacheRoot,
  PrepareMedia prepareMedia = prepareEntryMedia,
  Export? export,
  Quality? quality,
  Aspect? aspect,
  Time? posterTime,
  String? progressFile,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final video = entry.video();
  // The example injects its own resolver so the gate never reaches ffmpeg or the
  // network; a null one would have renderVideo build the real platform resolver.
  final resolver = await tester.runAsync(() => prepareMedia(video));

  return renderVideo(
    video: video,
    outDir: outDir,
    compositionKey: entry.key,
    frameCountOverride: frameCountOverride,
    cacheEnabled: cacheEnabled,
    cacheRoot: cacheRoot,
    aspect: aspect,
    quality: quality ?? Quality.high,
    export: export,
    posterTime: posterTime,
    resolver: resolver,
    snapshotService: const OfflineFakeSnapshotService(),
    beatDetector: offlineBeatDetector(),
    analyzer: offlineFrequencyAnalyzer(),
    // `flutter test` renders text that names no family with the Ahem font (every
    // glyph a filled box). The harness loads the real fonts, so name one here for
    // unstyled text, matching the platform goldens.
    defaultFontFamily: 'Roboto',
    setViewSize: (width, height) {
      tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
      tester.view.devicePixelRatio = 1.0;
    },
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(),
    runAsync: tester.runAsync,
    // Real-time progress for the CLI/inspector: write "<done>/<total>" to the
    // file the launcher polls. Off (null) for a plain `flutter test` run.
    onProgress: progressFile == null || progressFile.isEmpty
        ? null
        : (completed, total) => writeRenderProgress(progressFile, completed, total),
    onCacheReport: (hits, total) => stdout.writeln('fluvie-capture: cache hits $hits of $total'),
  );
}
