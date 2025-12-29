import 'package:json_annotation/json_annotation.dart';

part 'embedded_video_config.g.dart';

/// Configuration for embedded video in final encoding.
///
/// This configuration is used by the FFmpegFilterGraphBuilder to
/// generate overlay filters and audio mixing for embedded videos.
@JsonSerializable(explicitToJson: true)
class EmbeddedVideoConfig {
  /// Path to the video file.
  ///
  /// Can be an asset path, file path, or URL.
  final String videoPath;

  /// Frame in composition where video starts.
  final int startFrame;

  /// Duration in composition frames.
  final int durationInFrames;

  /// Trim offset from start of source video (in seconds).
  final double trimStartSeconds;

  /// Target width in output.
  final int width;

  /// Target height in output.
  final int height;

  /// X position in output canvas.
  final double positionX;

  /// Y position in output canvas.
  final double positionY;

  /// Whether to include audio from this video.
  final bool includeAudio;

  /// Audio volume (0.0 to 1.0).
  final double audioVolume;

  /// Audio fade-in frames.
  final int audioFadeInFrames;

  /// Audio fade-out frames.
  final int audioFadeOutFrames;

  /// Unique identifier for this embedded video.
  ///
  /// Used to generate unique filter labels in FFmpeg.
  final String id;

  const EmbeddedVideoConfig({
    required this.videoPath,
    required this.startFrame,
    required this.durationInFrames,
    required this.trimStartSeconds,
    required this.width,
    required this.height,
    this.positionX = 0,
    this.positionY = 0,
    this.includeAudio = true,
    this.audioVolume = 1.0,
    this.audioFadeInFrames = 0,
    this.audioFadeOutFrames = 0,
    required this.id,
  });

  /// End frame in composition timeline.
  int get endFrame => startFrame + durationInFrames;

  /// Start time in seconds for FFmpeg filters.
  double startTimeSeconds(int fps) => startFrame / fps;

  /// End time in seconds for FFmpeg filters.
  double endTimeSeconds(int fps) => endFrame / fps;

  /// Duration in seconds.
  double durationSeconds(int fps) => durationInFrames / fps;

  /// Creates a copy with updated values.
  EmbeddedVideoConfig copyWith({
    String? videoPath,
    int? startFrame,
    int? durationInFrames,
    double? trimStartSeconds,
    int? width,
    int? height,
    double? positionX,
    double? positionY,
    bool? includeAudio,
    double? audioVolume,
    int? audioFadeInFrames,
    int? audioFadeOutFrames,
    String? id,
  }) {
    return EmbeddedVideoConfig(
      videoPath: videoPath ?? this.videoPath,
      startFrame: startFrame ?? this.startFrame,
      durationInFrames: durationInFrames ?? this.durationInFrames,
      trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      includeAudio: includeAudio ?? this.includeAudio,
      audioVolume: audioVolume ?? this.audioVolume,
      audioFadeInFrames: audioFadeInFrames ?? this.audioFadeInFrames,
      audioFadeOutFrames: audioFadeOutFrames ?? this.audioFadeOutFrames,
      id: id ?? this.id,
    );
  }

  factory EmbeddedVideoConfig.fromJson(Map<String, dynamic> json) =>
      _$EmbeddedVideoConfigFromJson(json);

  Map<String, dynamic> toJson() => _$EmbeddedVideoConfigToJson(this);

  @override
  String toString() {
    return 'EmbeddedVideoConfig('
        'videoPath: $videoPath, '
        'startFrame: $startFrame, '
        'duration: $durationInFrames, '
        'trim: ${trimStartSeconds}s, '
        'size: ${width}x$height, '
        'pos: ($positionX, $positionY), '
        'audio: $includeAudio'
        ')';
  }
}
