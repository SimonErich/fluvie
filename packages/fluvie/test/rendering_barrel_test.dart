// The pipeline barrel: `package:fluvie/rendering.dart` is the single entry for
// render harnesses and encoder backends. One symbol per export group proves the
// whole surface is reachable from this barrel alone — capture, sandboxes,
// encoding seams, resolver contracts, and the renderer entry points.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';

void main() {
  group('the rendering barrel is the pipeline entry', () {
    test('the render entry points and their host seams are reachable', () {
      expect(render, isNotNull);
      expect(renderToSandbox, isNotNull);
      expect(renderTemplate, isNotNull);
      expect(frameCountFor(const Duration(seconds: 1), 30), 30);
      const RenderAspectResult? aspectResult = null;
      const ShellMount? mount = null;
      const ShellFramePump? pump = null;
      const SandboxMount? sandboxMount = null;
      const SandboxFramePump? sandboxPump = null;
      const FrameEncoder? encoder = null;
      expect([
        aspectResult,
        mount,
        pump,
        sandboxMount,
        sandboxPump,
        encoder,
      ], everyElement(isNull));
    });

    test('capture services, config, and progress are reachable', () {
      expect(const RepaintBoundaryCaptureService(), isA<FrameCaptureService>());
      expect(
        RenderConfig(width: 8, height: 8, frameCount: 1),
        isA<RenderConfig>(),
      );
      expect(
        RenderService(capture: const RepaintBoundaryCaptureService()),
        isA<RenderService>(),
      );
      expect(
        const RenderProgress(RenderPhase.capturing, compositionKey: 'k'),
        isA<RenderProgress>(),
      );
      const RenderProgressCallback? onProgress = null;
      expect(onProgress, isNull);
      expect(runStage, isNotNull);
      expect(runGuarded, isNotNull);
    });

    test('sandboxes and the raw-frame value types are reachable', () {
      final sandbox = MemoryRenderSandbox();
      expect(sandbox, isA<RenderSandbox>());
      expect(FileRenderSandbox, isNotNull);
      expect(
        RawFrame(frameIndex: 0, width: 1, height: 1, rgba: Uint8List(4)),
        isA<RawFrame>(),
      );
      expect(RenderManifest, isNotNull);
      expect(FrameCache.defaultRoot, isNotNull);
    });

    test('the ffmpeg runner seam is reachable', () {
      // The registry-selected runner is what RenderService.render requires; the
      // contract and its provider must live on this barrel.
      const FfmpegRunner? runner = null;
      expect(runner, isNull);
      expect(ffmpegRunnerProvider, isNotNull);
      expect(FfmpegRunnerRegistry, isNotNull);
      expect(WasmRuntime, isNotNull);
      expect(createWasmRuntime, isNotNull);
    });

    test('the resolver contracts and their defaults are reachable', () {
      expect(const NoMediaResolver(), isA<MediaResolver>());
      expect(const NoGenerativeResolver(), isA<GenerativeResolver>());
      expect(mediaResolverProvider, isNotNull);
      expect(generativeResolverProvider, isNotNull);
      expect(networkAllowlistProvider, isNotNull);
      expect(const NetworkAllowlist(hosts: {}), isA<NetworkAllowlist>());
      expect(resolverScope, isNotNull);
      const DisposableResolver? disposable = null;
      const SnapshotService? snapshots = null;
      const BeatDetectionService? beats = null;
      const FrequencyAnalyzer? bands = null;
      expect([disposable, snapshots, beats, bands], everyElement(isNull));
      expect(frameExtractionServiceProvider, isNotNull);
      expect(videoProbeServiceProvider, isNotNull);
      const FrameExtractionService? extraction = null;
      const VideoProbeService? probe = null;
      expect([extraction, probe], everyElement(isNull));
      expect(WebClipDecoder, isNotNull);
    });

    test('the audio-mix resolution seam is reachable', () {
      expect(resolveAudioMix, isNotNull);
      expect(stageResolvedAudioToSandbox, isNotNull);
      const AudioByteLoader? loader = null;
      const ResolvedAudioMix? mix = null;
      const ResolvedAudioTrack? track = null;
      expect([loader, mix, track], everyElement(isNull));
    });

    test('the media collectors and FadeBox primitive are reachable', () {
      expect(collectMediaSources, isNotNull);
      expect(collectSnapshotSources, isNotNull);
      expect(collectSnapshots, isNotNull);
      expect(FadeBox, isNotNull);
    });
  });
}
