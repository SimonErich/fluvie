import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/composition_registry.dart';

import 'harness_media.dart';
import 'harness_snapshot.dart';

/// The failure message the harness raises for an unregistered key, naming
/// every known key (asserted by the harness self-test).
String unknownKeyMessage(String key) =>
    'Unknown composition key "$key". Known keys: $knownCompositionKeys';

/// The `Export` for a `FLUVIE_RENDER_FORMAT` define (decision D-CLI), or `null`
/// (the mp4 default) for `null`/empty/`mp4`.
Export? parseExportFormat(String? format) => switch (format) {
  null || '' || 'mp4' => null,
  'gif' => const Export.gif(),
  'imageSequence' => const Export.imageSequence(),
  'transparent' => const Export.transparent(),
  _ => throw ArgumentError.value(format, 'format', 'unknown export format'),
};

/// The `Quality` for a `FLUVIE_RENDER_QUALITY` define, or `null` (the config
/// default) for `null`/empty.
Quality? parseQuality(String? quality) =>
    quality == null || quality.isEmpty ? null : Quality.values.byName(quality);

/// The `Aspect` for a `FLUVIE_RENDER_ASPECT` define, or `null` (the entry's
/// declared size) for `null`/empty.
Aspect? parseAspect(String? aspect) =>
    aspect == null || aspect.isEmpty ? null : Aspect.values.byName(aspect);

/// Parses a `FLUVIE_RENDER_POSTER` Time string (`1.5s`, `30f`, `500ms`), or
/// `null` for `null`/empty (no poster).
Time? parsePosterTime(String? poster) {
  if (poster == null || poster.isEmpty) return null;
  if (poster.endsWith('ms')) return Time.ms(int.parse(poster.substring(0, poster.length - 2)));
  if (poster.endsWith('s')) {
    return Time.seconds(double.parse(poster.substring(0, poster.length - 1)));
  }
  if (poster.endsWith('f')) return Time.frames(int.parse(poster.substring(0, poster.length - 1)));
  throw ArgumentError.value(poster, 'poster', 'expected a Time string like 1.5s, 30f or 500ms');
}

/// Counts real captures so the harness can report cache hits.
class _CountingCaptureService implements FrameCaptureService {
  int captures = 0;
  final FrameCaptureService _inner = const RepaintBoundaryCaptureService();

  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) {
    captures++;
    return _inner.capture(
      boundaryKey: boundaryKey,
      frameIndex: frameIndex,
      width: width,
      height: height,
    );
  }
}

/// Mounts [entry] in capture mode and renders it into [outDir]
/// (`frames.rgba` + `manifest.json`, manifest written last).
///
/// The pixel chain is fixed per decision D18: the view's physical size is the
/// entry's resolution at device pixel ratio 1.0, captures read back at
/// `pixelRatio: 1.0`. The whole capture runs inside `tester.runAsync` (real
/// IO and `toImage` need a real event loop); pumping happens via
/// `RenderController.seek` + `tester.pump` per frame.
///
/// Reports `fluvie-capture: cache hits <n> of <total>` on stdout so the CLI's
/// `--verbose` mode can surface cache behavior. [cacheRoot] overrides the
/// shared cache directory (self-tests pass a temp root; the CLI path uses the
/// default, which is what makes second runs hit).
Future<RenderManifest> runCaptureHarness({
  required WidgetTester tester,
  required CompositionEntry entry,
  required Directory outDir,
  int? frameCountOverride,
  bool cacheEnabled = true,
  Directory? cacheRoot,
  PrepareMedia prepareMedia = prepareEntryMedia,
  SnapshotScenes snapshotScenes = entryScenes,
  ReactiveTracksFor reactiveTracks = reactiveTracksFor,
  PrepareAudioStaging audioStaging = prepareEntryAudioStaging,
  Export? export,
  Quality? quality,
  Aspect? aspect,
  Time? posterTime,
  String? progressFile,
}) async {
  // An aspect define re-derives the canvas from aspect.sizeFor(longEdge), where
  // longEdge is the entry's longer side; absent, the entry's declared size wins
  // (a plain render is byte-identical). Only layout branches per aspect.
  final size = aspect?.sizeFor(entry.width > entry.height ? entry.width : entry.height);
  final width = size?.width ?? entry.width;
  final height = size?.height ?? entry.height;
  tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final config = RenderConfig(
    width: width,
    height: height,
    fps: entry.fps,
    frameCount: frameCountOverride ?? entry.frameCount,
    cacheEnabled: cacheEnabled,
    quality: quality ?? Quality.high,
  );
  // A poster Time resolves to an absolute frame against the render fps.
  final posterFrame = posterTime?.resolveFrames(
    TimeScopeData(fps: config.fps, startFrame: 0, durationFrames: config.frameCount),
  );
  final controller = RenderController();
  final boundaryKey = GlobalKey();

  // Media is resolved before the first frame so Image/Clip paint synchronously
  // (decision D3/D4). The resolved sources flow into RenderService for the
  // version-stable digest, and an ImageResolverScope carries the resolver down.
  MediaResolver? resolver;
  SnapshotCaptureScope? snapshotScope;
  await tester.runAsync(() async {
    resolver = await prepareMedia(entry);
    // The in-process Snapshot subtree-capture pre-pass (P12-SNAP wiring): after
    // media is decoded, rasterize every Snapshot child once under the resolver
    // (so an inner Image/Clip paints from the cache), then mount the resulting
    // scope above the composition. Without this a Snapshot in capture finds no
    // scope and re-rasterizes the live subtree every frame (a determinism
    // violation Snapshot.build now throws on).
    snapshotScope = await captureSnapshotScopeForScenes(
      tester: tester,
      scenes: snapshotScenes(entry),
      resolver: resolver,
      width: width,
      height: height,
    );
  });
  final capturedStills = snapshotScope?.images.values.toList() ?? const [];
  addTearDown(() {
    for (final image in capturedStills) {
      image.dispose();
    }
  });
  // The pre-pass repointed the view while rasterizing; restore the render size.
  tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
  tester.view.devicePixelRatio = 1.0;

  // The shared production capture shell (decision D-CaptureShell) builds the
  // whole scope chain — RenderModeContext > [SnapshotCaptureScope] >
  // RenderControllerScope > [ImageResolverScope] > RepaintBoundary >
  // [ReactiveScope] > [BeatGridScope] > composition — from the injected pre-pass
  // results. The example passes its offline fakes through the same injection
  // points the CLI uses (the resolver, the snapshot pre-pass scope, the reactive
  // tracks); only the flutter-test-only bits (view sizing, runAsync, the pump
  // loop below) stay here. The shell also serves Trigger.beat (via BeatGridScope)
  // and the reactive tables, so the example exercises the production path.
  final built = aspect == null ? entry.build() : AspectScope(aspect: aspect, child: entry.build());
  // `flutter test` renders text that names no family with the Ahem test font
  // (every glyph a filled box). The harness loads the real fonts (loadFonts), so
  // set a real default family for unstyled text, matching the platform goldens.
  final composition = DefaultTextStyle.merge(
    style: const TextStyle(fontFamily: 'Roboto'),
    child: built,
  );
  final shell = buildCaptureShell(
    composition: composition,
    boundaryKey: boundaryKey,
    controller: controller,
    resolver: resolver,
    snapshotScope: snapshotScope,
    reactiveTracks: resolver == null ? noReactiveTracks : reactiveTracks(entry),
  );
  // The mounted snapshot scope is one persistent instance re-pumped per frame,
  // so its order cursor must be reset before every frame's pump (the shell hands
  // it back so the harness resets the right instance — see the scope dartdoc).
  final mountedScope = shell.mountedSnapshotScope;
  await tester.pumpWidget(shell.tree);

  final counting = _CountingCaptureService();
  final service = RenderService(
    capture: counting,
    cache: FrameCache(cacheRoot ?? FrameCache.defaultRoot()),
    media: resolver ?? const NoMediaResolver(),
  );
  // The encoder audio mix (decision D-Audio / D-Mix): the entry's declared
  // `Audio` tracks become the `audioSources` the service materializes before the
  // frame loop and the `stageAudio` closure that builds the `-filter_complex`
  // mix. Without this the manifest carried `-an` and the render was silent — the
  // AUDMIX-WIRE fix. A track-less composition stages nothing (the demo stays
  // silent).
  final audio = audioStaging(entry, resolver);
  late final RenderManifest manifest;
  await tester.runAsync(() async {
    manifest = await service.captureToDirectory(
      config: config,
      outDir: outDir,
      pump: (frame) async {
        controller.seek(frame);
        // Restart the Snapshot order cursor so the n-th unkeyed Snapshot reads
        // index n this frame, not n + (frame * count) — otherwise the indices
        // drift and a later frame throws on a missing raster.
        mountedScope?.resetCursor();
        await tester.pump();
      },
      boundaryKey: boundaryKey,
      compositionKey: entry.key,
      audioSources: audio.audioSources,
      stageAudio: audio.stageAudio,
      export: export,
      posterFrame: posterFrame,
      // Real-time progress for the CLI/inspector: write "<done>/<total>" to the
      // file the launcher polls. Atomic (write-temp-then-rename) so a poller
      // never reads a torn count. Off (null) for a plain `flutter test` run.
      onProgress: progressFile == null
          ? null
          : (completed, total) => _writeProgress(progressFile, completed, total),
      // The harness pre-resolved every source above (images and clip frames
      // alike); the resolver is idempotent, so the service needs no re-pass —
      // and re-passing clip sources would try to decode an mp4 as an image.
    );
  });

  final hits = cacheEnabled ? config.frameCount - counting.captures : 0;
  stdout.writeln('fluvie-capture: cache hits $hits of ${config.frameCount}');
  return manifest;
}

/// Writes `"<completed>/<total>"` to [path] atomically: a sibling `.tmp` file is
/// written then renamed over [path], so a concurrent reader (the launcher's
/// poller) always sees a whole count, never a half-written one.
void _writeProgress(String path, int completed, int total) {
  File('$path.tmp')
    ..writeAsStringSync('$completed/$total', flush: true)
    ..renameSync(path);
}
