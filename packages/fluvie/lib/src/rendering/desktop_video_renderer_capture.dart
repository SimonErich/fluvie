part of 'desktop_video_renderer.dart';

extension _DesktopCapture on DesktopVideoRenderer {
  Future<File> _renderRequest(VideoRenderRequest request) async {
    final composition = request.composition;
    final fps = request.fps;
    final frameCount = request.frameCount;
    final cancellation = request.cancellation ?? this.cancellation;
    final onProgress = request.onProgress;
    final compositionKey = request.compositionKey;
    final audio = request.audio;
    cancellation?.throwIfCancelled();
    request.validateCapabilities(capabilities);
    final sandbox = await _sandboxFactory();
    final scope = resolverScope(
      mediaResolver,
      networkAllowlist: networkAllowlist,
      whenCancelled: cancellation?.whenCancelled,
    );
    var succeeded = false;
    try {
      onProgress?.call(RenderProgress(RenderPhase.capturing, compositionKey: compositionKey));
      final result = await runStage(
        RenderPhase.capturing,
        () => capture.render(
          // The host mounts this with no app ancestors, so the tree needs an
          // ambient Directionality for Text/RichText to lay out. Audio is
          // collected from the raw Video by the capture entry itself, so the
          // wrap is mount-only.
          composition: composition,
          aspect: request.aspect ?? Aspect.square,
          frameCount: frameCount,
          outDir: sandbox,
          service: _service,
          pumpWidget: (tree) async {
            cancellation?.throwIfCancelled();
            await pumpWidget(Directionality(textDirection: TextDirection.ltr, child: tree));
          },
          pumpFrame: () async {
            cancellation?.throwIfCancelled();
            await pumpFrame();
            cancellation?.throwIfCancelled();
          },
          longEdge: request.width > request.height ? request.width : request.height,
          fps: fps,
          quality: request.config.quality,
          request: request,
          cancellation: cancellation,
          onPrepared: (prepared, effective) {
            effective.validateCapabilities(capabilities);
            if (!audio) {
              gateOptInAudio(
                composition: prepared.video ?? composition,
                encode: false,
                warn: request.warnOnDroppedAudio,
                fps: fps,
                frameCount: prepared.totalFrames,
                warnSink: _onWarning,
                platformLabel: capabilities.backend,
                clipMetadata: scope.resolver.clipMetadataFor,
                clipTimeline: (source) => clipTimelineFor(scope.resolver, source),
                mountedClipPlans: prepared.clipAudioPlans,
              );
            }
          },
          compositionKey: compositionKey,
          stageAudio: audio ? null : _silentAudio,
          resolver: scope.resolver,
        ),
      );
      cancellation?.throwIfCancelled();
      final manifest = result.manifest;
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      await runStage(RenderPhase.encoding, () async {
        await (_runner ?? ProcessFfmpegRunner(cancellation: cancellation)).encode(
          args: manifest.ffmpegArgs,
          sandbox: sandbox,
        );
        final posterArgs = manifest.posterArgs;
        if (posterArgs != null) {
          await (_runner ?? ProcessFfmpegRunner(cancellation: cancellation)).encode(
            args: posterArgs,
            sandbox: sandbox,
          );
        }
      });
      cancellation?.throwIfCancelled();
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      succeeded = true;
      return File('${sandbox.path}/${manifest.outputFileName}');
    } finally {
      await runGuarded([
        scope.dispose,
        if (!succeeded)
          () async {
            if (sandbox.existsSync()) await sandbox.delete(recursive: true);
          },
      ], (error, _) => _onWarning('Cleanup after render failed: $error'));
    }
  }
}
