part of 'on_device_video_renderer.dart';

extension _NativeRenderPipeline on OnDeviceVideoRenderer {
  Future<File> _renderRequest(
    VideoRenderRequest request, {
    MobileVideoCodec? codec,
    int? bitRate,
    File? outputFile,
  }) async {
    final composition = request.composition;
    final fps = request.fps;
    final frameCount = request.frameCount;
    final cancellation = request.cancellation ?? this.cancellation;
    final onProgress = request.onProgress;
    final compositionKey = request.compositionKey;
    final audio = request.audio;
    final warnOnDroppedAudio = request.warnOnDroppedAudio;
    cancellation?.throwIfCancelled();
    request.validateCapabilities(capabilities);
    var effective = request;
    PreparedComposition? prepared;
    final size = Size(request.width.toDouble(), request.height.toDouble());
    final sandbox = await _sandboxFactory();
    final host = _hostFactory(size);
    final materializer = _audioMaterializer ?? BundleAudioMaterializer(cacheDir: sandbox);
    final ownedPcm = pcmDecoder == null
        ? NativePcmDecoder(cacheDir: sandbox, materializer: materializer)
        : null;
    final decoder = pcmDecoder ?? ownedPcm!;
    // Build the media resolver with the device-native clip seams (probe +
    // frame extraction via MediaMetadataRetriever, no ffmpeg). resolverScope is
    // bypassed here because it is shared with the web encoder and cannot import
    // the io-only clip providers.
    final ownedContainer = mediaResolver == null
        ? ProviderContainer(
            overrides: [
              mediaCancellationProvider.overrideWithValue(cancellation?.whenCancelled),
              frameExtractionServiceProvider.overrideWithValue(
                const NativeFrameExtractionService(),
              ),
              videoProbeServiceProvider.overrideWithValue(
                const NativeVideoProbeService(),
              ),
              if (networkAllowlist != null)
                networkAllowlistProvider.overrideWithValue(networkAllowlist!),
            ],
          )
        : null;
    final resolver = mediaResolver ?? ownedContainer!.read<MediaResolver>(mediaResolverProvider);
    try {
      onProgress?.call(RenderProgress(RenderPhase.capturing, compositionKey: compositionKey));
      final captured = await runStage(
        RenderPhase.capturing,
        () => _captureToSandbox(
          // The offscreen capture host mounts this with no app ancestors, so the
          // tree needs an ambient Directionality for Text/RichText to lay out
          // (the CLI capture harness wraps the same way). _resolveAudioTracks
          // below reads the raw Video, so the wrap stays off the audio path.
          composition: composition,
          aspect: request.aspect ?? Aspect.square,
          frameCount: frameCount,
          outDir: sandbox,
          service: _service,
          pumpWidget: (tree) async {
            cancellation?.throwIfCancelled();
            await host.mount(Directionality(textDirection: TextDirection.ltr, child: tree));
            cancellation?.throwIfCancelled();
          },
          pumpFrame: () async {
            cancellation?.throwIfCancelled();
            await host.pumpFrame();
            cancellation?.throwIfCancelled();
          },
          longEdge: request.width > request.height ? request.width : request.height,
          request: request,
          cancellation: cancellation,
          beatDetector: SpectralBeatDetectionService(decoder: decoder),
          analyzer: SpectralFrequencyAnalyzer(decoder: decoder),
          onPrepared: (snapshot, resolved) {
            prepared = snapshot;
            effective = resolved..validateCapabilities(capabilities);
          },
          fps: fps,
          compositionKey: compositionKey,
          resolver: resolver,
        ),
      );
      cancellation?.throwIfCancelled();
      final manifest = captured.manifest;
      final mix = await _resolveAudioTracks(
        prepared!.video ?? composition,
        mountedClipPlans: prepared!.clipAudioPlans,
        authoredFrames: prepared!.totalFrames,
        encode: audio,
        warn: warnOnDroppedAudio,
        fps: fps,
        frameCount: frameCount + request.startFrame,
        materializer: materializer,
        sandbox: sandbox,
        warnSink: _onWarning,
        resolver: resolver,
      );
      cancellation?.throwIfCancelled();
      final outputPath = outputFile?.path ?? '${sandbox.path}/${manifest.outputFileName}';
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      await runStage(
        RenderPhase.encoding,
        () => _encoder.encode(
          MobileEncodeRequest(
            framesPath: '${sandbox.path}/${manifest.framesFileName}',
            outputPath: outputPath,
            width: manifest.width,
            height: manifest.height,
            fps: manifest.fps,
            frameCount: manifest.frameCount,
            bitRate:
                bitRate ??
                effective.export?.bitRate ??
                defaultBitRate(width: manifest.width, height: manifest.height, fps: manifest.fps),
            codec:
                codec ??
                (effective.export?.codec == ExportCodec.h265
                    ? MobileVideoCodec.hevc
                    : MobileVideoCodec.h264),
            audioTracks: mix.tracks,
            audioMasterVolume: mix.masterVolume,
            audioStartSeconds: request.startFrame / fps,
          ),
        ),
      );
      cancellation?.throwIfCancelled();
      if (effective.posterFrame case final poster?) {
        await writeNativePoster(
          frames: File('${sandbox.path}/${manifest.framesFileName}'),
          output: File('${File(outputPath).parent.path}/poster.png'),
          frame: poster,
          width: manifest.width,
          height: manifest.height,
        );
      }
      cancellation?.throwIfCancelled();
      final completedManifest = manifest.toJson();
      completedManifest['outputIntent'] = {
        'width': manifest.width,
        'height': manifest.height,
        'fps': manifest.fps.toDouble(),
        'frameCount': manifest.frameCount,
        'durationSeconds': manifest.frameCount / manifest.fps,
        'codec':
            (codec ??
                    (effective.export?.codec == ExportCodec.h265
                        ? MobileVideoCodec.hevc
                        : MobileVideoCodec.h264))
                .wireName,
        'container': 'mp4',
        'hasAudio': mix.tracks.isNotEmpty,
        'hasAlpha': false,
      };
      await File('${sandbox.path}/manifest.json').writeAsString(jsonEncode(completedManifest));
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      return File(outputPath);
    } on Object {
      if (sandbox.existsSync()) await sandbox.delete(recursive: true);
      rethrow;
    } finally {
      await runGuarded([
        host.dispose,
        if (ownedPcm != null) ownedPcm.dispose,
        () async {
          // Only dispose the resolver this render built; a caller-injected
          // resolver is the caller's to dispose.
          if (ownedContainer != null && resolver is DisposableResolver) {
            (resolver as DisposableResolver).dispose();
          }
          ownedContainer?.dispose();
        },
      ], (error, _) => _onWarning('Cleanup after render failed: $error'));
    }
  }
}
