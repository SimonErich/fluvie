import 'package:json_annotation/json_annotation.dart';

import 'audio_config.dart';
import 'embedded_video_config.dart';
import 'spatial_properties.dart';

part 'render_config.g.dart';

/// Configuration for rendering a video composition.
///
/// This is the serializable representation of a video composition
/// that can be passed to the encoder service.
@JsonSerializable(explicitToJson: true)
class RenderConfig {
  /// Timeline settings (fps, duration, dimensions).
  final TimelineConfig timeline;

  /// List of sequences in the composition.
  final List<SequenceConfig> sequences;

  /// Audio tracks to be mixed into the video.
  final List<AudioTrackConfig> audioTracks;

  /// Embedded video files to overlay on the composition.
  final List<EmbeddedVideoConfig> embeddedVideos;

  /// Encoding configuration (quality, codec options).
  final EncodingConfig? encoding;

  /// Creates a render configuration.
  RenderConfig({
    required this.timeline,
    required this.sequences,
    this.audioTracks = const [],
    this.embeddedVideos = const [],
    this.encoding,
  });

  factory RenderConfig.fromJson(Map<String, dynamic> json) =>
      _$RenderConfigFromJson(json);
  Map<String, dynamic> toJson() => _$RenderConfigToJson(this);
}

/// Timeline configuration for a video composition.
@JsonSerializable()
class TimelineConfig {
  /// Frames per second.
  final int fps;

  /// Total duration in frames.
  final int durationInFrames;

  /// Output video width in pixels.
  final int width;

  /// Output video height in pixels.
  final int height;

  /// Creates a timeline configuration.
  TimelineConfig({
    required this.fps,
    required this.durationInFrames,
    required this.width,
    required this.height,
  });

  factory TimelineConfig.fromJson(Map<String, dynamic> json) =>
      _$TimelineConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineConfigToJson(this);
}

/// Type discriminator for polymorphic sequence configs.
@JsonEnum(fieldRename: FieldRename.snake)
enum SequenceType {
  /// Base sequence type.
  base,

  /// Video file sequence.
  video,

  /// Text sequence.
  text,

  /// Composite sequence with children.
  composite,
}

/// Configuration for a single sequence in the composition.
///
/// This class represents different types of sequences using a type discriminator.
/// Use the factory constructors for type-safe creation:
/// - [SequenceConfig.base] for simple sequences
/// - [SequenceConfig.video] for video file sequences
/// - [SequenceConfig.text] for text sequences
/// - [SequenceConfig.composite] for nested sequences
@JsonSerializable()
class SequenceConfig {
  /// The type of this sequence.
  final SequenceType type;

  /// Frame number where this sequence starts.
  final int startFrame;

  /// Duration of this sequence in frames.
  final int durationInFrames;

  /// Spatial properties (position, scale, rotation, opacity).
  final SpatialProperties? spatialProps;

  /// Child sequences (for composite type).
  final List<SequenceConfig>? children;

  /// Path to video asset (for video type).
  final String? assetPath;

  /// Trim start frame for video assets.
  final int? trimStartFrame;

  /// Trim duration in frames for video assets.
  final int? trimDurationInFrames;

  /// Text content (for text type).
  final String? text;

  /// Creates a sequence configuration.
  ///
  /// Prefer using the type-safe factory constructors instead.
  const SequenceConfig({
    this.type = SequenceType.base,
    required this.startFrame,
    required this.durationInFrames,
    this.spatialProps,
    this.children,
    this.assetPath,
    this.trimStartFrame,
    this.trimDurationInFrames,
    this.text,
  });

  /// Creates a base sequence configuration.
  const SequenceConfig.base({
    required this.startFrame,
    required this.durationInFrames,
    this.spatialProps,
  })  : type = SequenceType.base,
        children = null,
        assetPath = null,
        trimStartFrame = null,
        trimDurationInFrames = null,
        text = null;

  /// Creates a video sequence configuration.
  ///
  /// [assetPath] is required and specifies the path to the video file.
  const SequenceConfig.video({
    required this.startFrame,
    required this.durationInFrames,
    required String this.assetPath,
    this.trimStartFrame,
    this.trimDurationInFrames,
    this.spatialProps,
  })  : type = SequenceType.video,
        children = null,
        text = null;

  /// Creates a text sequence configuration.
  ///
  /// [text] is required and specifies the text content.
  const SequenceConfig.text({
    required this.startFrame,
    required this.durationInFrames,
    required String this.text,
    this.spatialProps,
  })  : type = SequenceType.text,
        children = null,
        assetPath = null,
        trimStartFrame = null,
        trimDurationInFrames = null;

  /// Creates a composite sequence with child sequences.
  const SequenceConfig.composite({
    required this.startFrame,
    required this.durationInFrames,
    required List<SequenceConfig> this.children,
    this.spatialProps,
  })  : type = SequenceType.composite,
        assetPath = null,
        trimStartFrame = null,
        trimDurationInFrames = null,
        text = null;

  /// Whether this is a video sequence.
  bool get isVideo => type == SequenceType.video;

  /// Whether this is a text sequence.
  bool get isText => type == SequenceType.text;

  /// Whether this is a composite sequence.
  bool get isComposite => type == SequenceType.composite;

  factory SequenceConfig.fromJson(Map<String, dynamic> json) =>
      _$SequenceConfigFromJson(json);
  Map<String, dynamic> toJson() => _$SequenceConfigToJson(this);
}

/// Frame capture format for the rendering pipeline.
@JsonEnum(fieldRename: FieldRename.snake)
enum FrameFormat {
  /// Raw RGBA pixel data (fastest, no encoding overhead).
  rawRgba,

  /// PNG encoded frames (supports transparency in output).
  png,
}

/// Video render quality presets.
@JsonEnum(fieldRename: FieldRename.snake)
enum RenderQuality {
  /// Fast encoding, larger file size (CRF 30, veryfast preset).
  low,

  /// Balanced quality and speed (CRF 23, medium preset).
  medium,

  /// High quality, slower encoding (CRF 18, slow preset).
  high,

  /// Lossless quality, slowest encoding (CRF 0, veryslow preset).
  lossless,
}

/// Encoding configuration for video output.
@JsonSerializable()
class EncodingConfig {
  /// Quality preset.
  final RenderQuality quality;

  /// Override the CRF value (0-51, lower is better quality).
  final int? crfOverride;

  /// Override the FFmpeg preset (ultrafast, superfast, veryfast, faster,
  /// fast, medium, slow, slower, veryslow).
  final String? presetOverride;

  /// Frame capture format.
  ///
  /// Use `FrameFormat.rawRgba` for fastest capture (default).
  /// Use `FrameFormat.png` when transparency is needed in the output.
  final FrameFormat frameFormat;

  /// Creates encoding configuration.
  const EncodingConfig({
    this.quality = RenderQuality.medium,
    this.crfOverride,
    this.presetOverride,
    this.frameFormat = FrameFormat.rawRgba,
  });

  factory EncodingConfig.fromJson(Map<String, dynamic> json) =>
      _$EncodingConfigFromJson(json);
  Map<String, dynamic> toJson() => _$EncodingConfigToJson(this);
}
