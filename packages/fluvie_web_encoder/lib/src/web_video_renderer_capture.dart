part of 'web_video_renderer.dart';

extension _BrowserCapture on WebVideoRenderer {
  Future<Uint8List> _renderRequest(VideoRenderRequest request) async {
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
    final sandbox = MemoryRenderSandbox();
    final host = _hostFactory(Size(request.width.toDouble(), request.height.toDouble()));
    final scope = resolverScope(
      mediaResolver,
      networkAllowlist: networkAllowlist,
      whenCancelled: cancellation?.whenCancelled,
      clipDecoder: _clipDecoder,
    );
    try {
      final manifest = await runStage(
        RenderPhase.capturing,
        () => renderToSandbox(
          // The offscreen capture host mounts this with no app ancestors, so the
          // tree needs an ambient Directionality for Text/RichText to lay out.
          composition: composition,
          aspect: request.aspect ?? Aspect.square,
          frameCount: frameCount,
          sandbox: sandbox,
          capture: const RepaintBoundaryCaptureService(),
          pumpWidget: (tree) =>
              host.mount(Directionality(textDirection: TextDirection.ltr, child: tree)),
          pumpFrame: () async {
            cancellation?.throwIfCancelled();
            await host.pumpFrame();
            cancellation?.throwIfCancelled();
          },
          longEdge: request.width > request.height ? request.width : request.height,
          request: request,
          cancellation: cancellation,
          onPrepared: (prepared, resolved) {
            effective = resolved..validateCapabilities(capabilities);
          },
          fps: fps,
          compositionKey: compositionKey,
          export: effective.export,
          posterFrame: effective.posterFrame,
          onProgress: (completed, total) => onProgress?.call(
            RenderProgress(
              RenderPhase.capturing,
              completedFrames: completed,
              totalFrames: total,
              compositionKey: compositionKey,
            ),
          ),
          resolveAudio: (session) => gateOptInAudio(
            composition: session.video ?? composition,
            encode: audio,
            warn: warnOnDroppedAudio,
            export: effective.export,
            fps: fps,
            frameCount: session.prepared.totalFrames,
            warnSink: _onWarning,
            platformLabel: 'in-browser',
            clipMetadata: scope.resolver.clipMetadataFor,
            clipTimeline: (source) => clipTimelineFor(scope.resolver, source),
            mountedClipPlans: session.clipAudioPlans,
          ),
          loadAudioBytes: _audioMaterializer.materialize,
          resolver: scope.resolver,
          frameEncoder: _frameEncoder,
        ),
      );
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      final bytes = await runStage(
        RenderPhase.encoding,
        () => _encoder.encode(manifest: manifest, sandbox: sandbox, cancellation: cancellation),
      );
      cancellation?.throwIfCancelled();
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      return bytes;
    } finally {
      await runGuarded([
        host.dispose,
        scope.dispose,
        () async => sandbox.clear(),
      ], (error, _) => _onWarning('Cleanup after render failed: $error'));
    }
  }
}
