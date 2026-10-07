part of 'render_host.dart';

Future<Map<String, Object>> _prepareOperation(
  RenderHostContext host,
  MediaResolver resolver, {
  FutureOr<Video> Function()? videoFactory,
}) async {
  final request = host.invocation;
  final video = host.video;
  final review = request.operation == 'review';
  final mounted = _MountedHostComposition(host, video, resolver);
  final width = mounted.width;
  final height = mounted.height;
  final session = mounted.session;
  try {
    await mounted.prepare();
    final file = File(
      '${request.outputDir}/${request.operation == 'audio'
          ? 'audio-mix.json'
          : review
          ? 'review.json'
          : 'inspection.json'}',
    );
    final data = <String, Object?>{
      'schemaVersion': 1,
      'fps': video.fps,
      'width': width,
      'height': height,
      'totalFrames': video.totalFrames,
    };
    if (request.operation == 'audio') {
      final audio = await host.runAsync(() => _prepareAudioMix(host, session, resolver));
      if (audio == null) throw StateError('Audio preparation returned no mix.');
      data.addAll(audio);
    } else {
      data.addAll({
        'scenes': [
          for (var i = 0; i < video.scenes.length; i++)
            {
              'index': i,
              'startFrame': video.sceneStartFrames[i],
              'duration': '${video.scenes[i].duration}',
            },
        ],
        'media': [
          for (final source in session.mediaSources) {'source': '$source'},
        ],
        'clips': [
          for (final plan in session.clipPlans)
            {
              'source': '${plan.source}',
              'windowStart': plan.windowStart,
              'windowFrames': plan.windowLength,
              'metadata': _metadataJson(resolver.clipMetadataFor(plan.source)),
            },
        ],
        'hasAudio':
            collectAudioTracks(video).isNotEmpty ||
            session.clipAudioPlans.any(
              (plan) => plan.speed >= 0 && resolver.clipMetadataFor(plan.source).hasAudio,
            ),
      });
    }
    if (review) {
      data.addAll(
        await _captureReview(
          host: host,
          mounted: mounted,
          videoFactory: videoFactory,
        ),
      );
    }
    await host.runAsync(() async {
      await file.writeAsString(jsonEncode(data), flush: true);
      return null;
    });
    return {'kind': request.operation, 'filePath': file.absolute.path};
  } finally {
    await mounted.close();
  }
}

Map<String, Object> _metadataJson(ClipMetadata meta) => {
  'fps': meta.fps,
  'frameCount': meta.frameCount,
  'width': meta.width,
  'height': meta.height,
  'hasAudio': meta.hasAudio,
};

Aspect _aspectFor(Video video) {
  for (final aspect in Aspect.values) {
    final size = aspect.sizeFor(video.width > video.height ? video.width : video.height);
    if (size.width == video.width && size.height == video.height) return aspect;
  }
  throw ArgumentError(
    'VideoRenderer uses an Aspect canvas. This video is ${video.width}×${video.height}; '
    'provide --aspect or use --harness with renderVideo for arbitrary canvas dimensions.',
  );
}

String _extension(String path) {
  final name = path.replaceAll(r'\', '/').split('/').last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '.mp4' : name.substring(dot);
}
