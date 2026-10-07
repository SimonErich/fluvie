part of 'render_host.dart';

Future<Map<String, Object>> _renderCustom(
  RenderHostContext host,
  RenderFactory factory,
  String captureKey,
) async {
  final request = host.invocation;
  final video = host.video;
  final result = <String, Object>{};
  if (request.operation != 'render') {
    throw ArgumentError(
      'Custom renderers support the render operation; use the default host for ${request.operation}.',
    );
  }
  final size = request.aspect?.sizeFor(video.width > video.height ? video.width : video.height);
  final frames = request.frameCount ?? video.totalFrames;
  final authoredPoster = (request.posterTime ?? video.poster)?.resolveFrames(
    TimeScopeData(fps: video.fps, startFrame: 0, durationFrames: video.totalFrames),
  );
  final renderRequest = VideoRenderRequest(
    composition: DefaultAssetBundle(bundle: host.assets, child: video),
    width: size?.width ?? video.width,
    height: size?.height ?? video.height,
    frameCount: frames,
    fps: video.fps,
    aspect: request.aspect,
    export: request.export,
    quality: request.quality,
    posterFrame: authoredPoster != null && authoredPoster >= 0 && authoredPoster < frames
        ? authoredPoster
        : null,
    compositionKey: captureKey,
    onProgress: host.onProgress,
    cancellation: host.cancellation,
  ).withAuthoredOptions(authoredExport: video.export);
  host.renderRequest = renderRequest;
  host.setViewSize(renderRequest.width, renderRequest.height);
  final renderer = await factory(host);
  late final File file;
  await host.runAsync(() async {
    if (renderer is RequestVideoRenderer<File>) {
      final adapter = renderer as RequestVideoRenderer<File>;
      renderRequest.validateCapabilities(adapter.capabilities);
      file = await adapter.renderRequest(renderRequest);
    } else {
      if (renderRequest.export != null ||
          request.quality != null ||
          renderRequest.posterFrame != null) {
        throw FluvieCapabilityException(
          capability: 'Complete export and poster settings',
          host: 'the legacy VideoRenderer adapter',
          remedy:
              'Implement RequestVideoRenderer<File> alongside VideoRenderer<File> and handle renderRequest.',
        );
      }
      final aspect = request.aspect ?? _aspectFor(video);
      file = await renderer.render(
        composition: renderRequest.composition,
        aspect: aspect,
        duration: Duration(
          microseconds: (frames * Duration.microsecondsPerSecond / video.fps).round(),
        ),
        fps: video.fps,
        longEdge: video.width > video.height ? video.width : video.height,
        audio: renderRequest.audio,
        compositionKey: captureKey,
        onProgress: host.onProgress,
      );
    }
    return null;
  });
  host.cancellation.throwIfCancelled();
  await host.runAsync(() async {
    if (!file.existsSync()) {
      throw StateError('Custom renderer returned a missing file: ${file.path}');
    }
    final staged = File('${request.outputDir}/encoded${_extension(file.path)}');
    if (file.absolute.path != staged.absolute.path) await file.copy(staged.path);
    result.addAll({'kind': 'encoded', 'filePath': staged.absolute.path});
    final backendManifest = File('${file.parent.path}/manifest.json');
    if (backendManifest.existsSync()) {
      final manifest = jsonDecode(await backendManifest.readAsString());
      if (manifest is Map && manifest['outputIntent'] is Map) {
        result['outputIntent'] = Map<String, Object?>.from(manifest['outputIntent'] as Map);
      }
    }
    return null;
  });
  return result;
}
