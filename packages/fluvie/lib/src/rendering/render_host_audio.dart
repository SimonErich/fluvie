part of 'render_host.dart';

Future<Map<String, Object?>> _prepareAudioMix(
  RenderHostContext host,
  CompositionSession session,
  MediaResolver resolver,
) async {
  final request = host.invocation;
  final video = host.video;
  final tracks = collectAudioTracks(video);
  final clips = session.clipAudioPlans
      .where((plan) => plan.speed >= 0 && resolver.clipMetadataFor(plan.source).hasAudio)
      .toList();
  final sources = <AudioSource>{
    ...tracks.map((track) => track.audioSource),
    ...clips.map((clip) => clipAudioSourceFor(clip.source)),
  };
  await resolver.preResolveAudio(sources);
  final nodes = await stageClipAudio(
    plans: clips,
    resolver: resolver,
    sandbox: Directory(request.outputDir),
    fps: video.fps,
    totalFrames: video.totalFrames,
  );
  final mix = await stageAudioMix(
    tracks: tracks,
    resolver: resolver,
    sandbox: Directory(request.outputDir),
    fps: video.fps,
    totalFrames: video.totalFrames,
    extraNodes: nodes,
  );
  final duration = video.totalFrames / video.fps;
  final args = <String>['-y'];
  if (mix.isEmpty) {
    args.addAll(['-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000']);
  } else {
    final filters = <String>[];
    final labels = <String>[];
    for (var i = 0; i < mix.tracks.length; i++) {
      final label = 'audio$i';
      args.addAll(mix.tracks[i].inputArgs());
      filters.add(mix.tracks[i].filterChain(inputIndex: i, label: label));
      labels.add(label);
    }
    filters
      ..add(mix.amix!.mixChain(labels: labels, outLabel: 'mixed'))
      ..add('[mixed]apad,atrim=end=$duration[preview]');
    args.addAll(['-filter_complex', filters.join(';'), '-map', '[preview]']);
  }
  args.addAll([
    '-vn',
    '-t',
    '$duration',
    '-ac',
    '2',
    '-ar',
    '48000',
    '-c:a',
    'pcm_s16le',
    'audio.wav',
  ]);
  return {
    'silent': mix.isEmpty,
    'durationSeconds': duration,
    'sampleRate': 48000,
    'channels': 2,
    'ffmpegArgs': args,
    'outputFileName': 'audio.wav',
  };
}
