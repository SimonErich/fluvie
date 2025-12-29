import 'dart:math' as math;

import '../domain/audio_config.dart';
import '../domain/embedded_video_config.dart';
import '../domain/render_config.dart';
import '../utils/logger.dart';

/// Builds FFmpeg filter graphs for video compositions.
///
/// Handles:
/// - Base video processing (fps, format conversion)
/// - Audio extraction from embedded videos (video frames are already in PNG sequence)
/// - Audio track mixing with trim, fade, volume, and delay
class FFmpegFilterGraphBuilder {
  /// Builds a complete filter graph from render configuration.
  ///
  /// The filter graph handles:
  /// 1. Base video: fps and format conversion (video frames from EmbeddedVideo
  ///    widgets are already rendered into the PNG sequence by Flutter)
  /// 2. Audio from embedded videos: extracted from video inputs for sync
  /// 3. Separate audio tracks: trimmed, faded, and mixed
  ///
  /// Note: Embedded video FRAMES are NOT overlaid - they are already captured
  /// in the PNG sequence by the EmbeddedVideo widget. Only AUDIO is extracted
  /// from the embedded video files.
  ///
  /// Input order in FFmpeg command:
  /// - Input 0: Composition frames (rawvideo/png from stdin)
  /// - Inputs 1..N: Embedded video files (AUDIO ONLY - video stream ignored)
  /// - Inputs N+1..: Separate audio files (background music, etc.)
  FFmpegFilterGraph build(RenderConfig config) {
    final sections = <String>[];
    final fps = config.timeline.fps;

    // Determine how many video inputs we have
    // Input 0 is always the composition frames
    // Inputs 1..N are embedded videos (for audio extraction only)
    // Remaining inputs are separate audio tracks
    final embeddedVideoCount = config.embeddedVideos.length;
    final firstSeparateAudioInput = 1 + embeddedVideoCount;

    // Build video filter chain
    // Note: We do NOT overlay embedded videos - their frames are already in the PNG sequence
    // The EmbeddedVideo widget renders video frames into Flutter, which are captured as PNGs
    sections.add('[0:v] fps=$fps,format=yuv420p [v_out]');

    // Count audio sources: embedded videos with audio + separate audio tracks
    // Only count videos that have includeAudio=true AND have a valid duration
    final embeddedVideosWithAudio = config.embeddedVideos
        .where((v) => v.includeAudio && v.durationInFrames > 0)
        .toList();
    final hasEmbeddedAudio = embeddedVideosWithAudio.isNotEmpty;
    final hasSeparateAudio = config.audioTracks.isNotEmpty;
    final hasAnyAudio = hasEmbeddedAudio || hasSeparateAudio;

    // Build audio filter chain
    if (hasAnyAudio) {
      sections.addAll(
        _buildCombinedAudioSections(config, fps, firstSeparateAudioInput),
      );
    }

    final graph = sections.join(';');

    // Log filter graph summary
    final logLines = <String>[
      'embeddedVideoCount: $embeddedVideoCount',
      'embeddedVideosWithAudio: ${embeddedVideosWithAudio.length}',
    ];
    for (var i = 0; i < config.embeddedVideos.length; i++) {
      final v = config.embeddedVideos[i];
      logLines.add(
        '  Video $i: includeAudio=${v.includeAudio}, duration=${v.durationInFrames}, startFrame=${v.startFrame}',
      );
    }
    logLines.addAll([
      'hasEmbeddedAudio: $hasEmbeddedAudio',
      'hasSeparateAudio: $hasSeparateAudio (${config.audioTracks.length} tracks)',
      'hasAnyAudio: $hasAnyAudio',
      'audioOutputLabel: ${hasAnyAudio ? '[a_mix_out]' : 'NULL'}',
    ]);
    FluvieLogger.section('Filter Graph Summary', logLines, module: 'filter');

    return FFmpegFilterGraph(
      graph: graph,
      videoOutputLabel: '[v_out]',
      audioOutputLabel: hasAnyAudio ? '[a_mix_out]' : null,
      embeddedVideoCount: embeddedVideoCount,
    );
  }

  /// Builds combined audio filter sections from embedded videos and separate audio tracks.
  ///
  /// Audio from embedded videos is extracted from their video input streams ([1:a], [2:a], etc.)
  /// Separate audio tracks are loaded as additional inputs after the video inputs.
  List<String> _buildCombinedAudioSections(
    RenderConfig config,
    int fps,
    int firstSeparateAudioInput,
  ) {
    final sections = <String>[];
    final audioOutputLabels = <String>[];
    final fpsDouble = fps.toDouble();

    // Process audio from embedded videos
    for (var i = 0; i < config.embeddedVideos.length; i++) {
      final video = config.embeddedVideos[i];
      FluvieLogger.debug(
        'Video $i: includeAudio=${video.includeAudio}, '
        'startFrame=${video.startFrame}, duration=${video.durationInFrames}',
        module: 'filter',
      );
      if (!video.includeAudio) {
        FluvieLogger.debug(
          'Skipping audio for video $i (includeAudio=false)',
          module: 'filter',
        );
        continue;
      }
      if (video.durationInFrames <= 0) {
        FluvieLogger.debug(
          'Skipping audio for video $i (duration=${video.durationInFrames})',
          module: 'filter',
        );
        continue;
      }

      final videoInputIndex = i + 1; // Embedded videos start at input 1
      final inputLabel = '[$videoInputIndex:a]';
      final outputLabel = '[a_embedded_$i]';

      final filterChain = _buildEmbeddedVideoAudioFilterChain(
        video: video,
        fps: fpsDouble,
        inputLabel: inputLabel,
        outputLabel: outputLabel,
      );
      FluvieLogger.debug(
        'Audio filter for video $i: $filterChain',
        module: 'filter',
      );
      sections.add(filterChain);
      audioOutputLabels.add(outputLabel);
    }

    // Process separate audio tracks
    for (var i = 0; i < config.audioTracks.length; i++) {
      final track = config.audioTracks[i];
      final inputIndex = firstSeparateAudioInput + i;
      final inputLabel = '[$inputIndex:a]';
      final outputLabel = '[a_track_$i]';

      final filterChain = _buildAudioFilterChain(
        track: track,
        fps: fpsDouble,
        inputLabel: inputLabel,
        outputLabel: outputLabel,
      );
      sections.add(filterChain);
      audioOutputLabels.add(outputLabel);
    }

    // Mix all audio sources
    if (audioOutputLabels.length == 1) {
      // Single audio source - rename the last output to final output
      final lastSection = sections.removeLast();
      // Replace the output label with [a_mix_out]
      final updatedSection =
          '${lastSection.substring(0, lastSection.lastIndexOf('['))}[a_mix_out]';
      sections.add(updatedSection);
    } else if (audioOutputLabels.length > 1) {
      // Multiple audio sources - use amix to combine them
      final mixInputs = audioOutputLabels.join();
      sections.add(
        '$mixInputs'
        'amix=inputs=${audioOutputLabels.length}:duration=longest:dropout_transition=0'
        '[a_mix_out]',
      );
    }

    return sections;
  }

  /// Builds audio filter chain for an embedded video's audio stream.
  String _buildEmbeddedVideoAudioFilterChain({
    required EmbeddedVideoConfig video,
    required double fps,
    required String inputLabel,
    required String outputLabel,
  }) {
    final filters = <String>[];

    // Duration in seconds
    final durationSeconds = video.durationInFrames / fps;

    // Note: The video input already has -ss seek applied, so the audio is pre-trimmed
    // We just need to limit duration and apply effects

    // Trim to match video duration
    filters.add('atrim=start=0:end=$durationSeconds');
    filters.add('asetpts=PTS-STARTPTS');

    // Fade in
    if (video.audioFadeInFrames > 0) {
      final fadeInSeconds = video.audioFadeInFrames / fps;
      filters.add('afade=t=in:st=0:d=$fadeInSeconds');
    }

    // Fade out
    if (video.audioFadeOutFrames > 0) {
      final fadeOutSeconds = video.audioFadeOutFrames / fps;
      final fadeOutStart = math.max(durationSeconds - fadeOutSeconds, 0);
      filters.add('afade=t=out:st=$fadeOutStart:d=$fadeOutSeconds');
    }

    // Volume adjustment
    if (video.audioVolume != 1.0) {
      filters.add('volume=${video.audioVolume}');
    }

    // Delay to position in timeline (matching video start frame)
    final delayMs = (video.startFrame / fps * 1000).round();
    if (delayMs > 0) {
      filters.add('adelay=$delayMs|$delayMs');
    }

    final chain = filters.join(',');
    return '$inputLabel$chain$outputLabel';
  }

  /// Builds filter chain for a single audio track.
  String _buildAudioFilterChain({
    required AudioTrackConfig track,
    required double fps,
    required String inputLabel,
    required String outputLabel,
  }) {
    final filters = <String>[];

    // Convert frames to seconds for FFmpeg
    final trimStartSeconds = track.trimStartFrame / fps;
    final trimEndSeconds = track.trimEndFrame != null
        ? track.trimEndFrame! / fps
        : null;
    final durationSeconds = track.durationInFrames / fps;

    final desiredEndSeconds = trimStartSeconds + durationSeconds;
    final effectiveEndSeconds = trimEndSeconds != null
        ? math.min(trimEndSeconds, desiredEndSeconds)
        : desiredEndSeconds;

    // Trim filter
    if (trimStartSeconds > 0 || trimEndSeconds != null) {
      final buffer = StringBuffer('atrim=start=$trimStartSeconds');
      if (effectiveEndSeconds.isFinite) {
        buffer.write(':end=$effectiveEndSeconds');
      }
      filters.add(buffer.toString());
      filters.add('asetpts=PTS-STARTPTS');
    }

    // Loop if needed
    if (track.loop) {
      filters.add('aloop=loop=-1:size=0');
    }

    // Trim to final duration
    filters.add('atrim=start=0:end=$durationSeconds');
    filters.add('asetpts=PTS-STARTPTS');

    // Fade in
    if (track.fadeInFrames > 0) {
      final fadeInSeconds = track.fadeInFrames / fps;
      filters.add('afade=t=in:st=0:d=$fadeInSeconds');
    }

    // Fade out
    if (track.fadeOutFrames > 0) {
      final fadeOutSeconds = track.fadeOutFrames / fps;
      final fadeOutStart = math.max(durationSeconds - fadeOutSeconds, 0);
      filters.add('afade=t=out:st=$fadeOutStart:d=$fadeOutSeconds');
    }

    // Volume adjustment
    if (track.volume != 1.0) {
      filters.add('volume=${track.volume}');
    }

    // Delay for positioning in timeline
    final delayMs = (track.startFrame / fps * 1000).round();
    if (delayMs > 0) {
      filters.add('adelay=$delayMs|$delayMs');
    }

    final chain = filters.join(',');
    return '$inputLabel$chain$outputLabel';
  }
}

/// Result of building an FFmpeg filter graph.
class FFmpegFilterGraph {
  /// The complete filter graph string.
  final String graph;

  /// Label for the video output stream.
  final String videoOutputLabel;

  /// Label for the audio output stream (null if no audio).
  final String? audioOutputLabel;

  /// Number of embedded video inputs in the filter graph.
  final int embeddedVideoCount;

  const FFmpegFilterGraph({
    required this.graph,
    required this.videoOutputLabel,
    this.audioOutputLabel,
    this.embeddedVideoCount = 0,
  });
}
