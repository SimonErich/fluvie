import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:meta/meta.dart';

/// Everything one render needs to know: output size, frame rate, the frame
/// window to capture, encode [quality], and whether the frame cache may serve
/// repeated frames.
///
/// Hand-written immutable value class (no codegen). Validation
/// happens at construction: width and height must be even (yuv420p
/// chroma subsampling halves them), fps and frameCount positive, startFrame
/// non-negative — violations are programming errors ([ArgumentError]).
///
/// [toJson]/[RenderConfig.fromJson] round-trip the full config; the JSON form
/// feeds the render digest that keys the frame cache, so field names and the
/// `Quality.name` spelling are stable.
@immutable
final class RenderConfig {
  /// Creates a validated render configuration.
  RenderConfig({
    required this.width,
    required this.height,
    required this.frameCount,
    this.fps = VideoDefaults.fps,
    this.startFrame = 0,
    this.quality = Quality.high,
    this.cacheEnabled = true,
  }) {
    if (width <= 0 || width.isOdd) {
      throw ArgumentError.value(width, 'width', 'must be positive and even (yuv420p output)');
    }
    if (height <= 0 || height.isOdd) {
      throw ArgumentError.value(height, 'height', 'must be positive and even (yuv420p output)');
    }
    if (fps <= 0) {
      throw ArgumentError.value(fps, 'fps', 'must be positive');
    }
    if (frameCount <= 0) {
      throw ArgumentError.value(frameCount, 'frameCount', 'must be positive');
    }
    if (startFrame < 0) {
      throw ArgumentError.value(startFrame, 'startFrame', 'must be >= 0');
    }
  }

  /// Reads a config from its [toJson] form (validating as the constructor).
  factory RenderConfig.fromJson(Map<String, Object?> json) => RenderConfig(
    width: json['width']! as int,
    height: json['height']! as int,
    fps: json['fps']! as int,
    frameCount: json['frameCount']! as int,
    startFrame: json['startFrame']! as int,
    quality: Quality.values.byName(json['quality']! as String),
    cacheEnabled: json['cacheEnabled']! as bool,
  );

  /// Output width in pixels (even, for yuv420p).
  final int width;

  /// Output height in pixels (even, for yuv420p).
  final int height;

  /// Frames per second of the output video.
  final int fps;

  /// How many frames to capture and encode.
  final int frameCount;

  /// The first frame to capture (the loop runs `startFrame ..
  /// startFrame + frameCount - 1`).
  final int startFrame;

  /// Encode quality level (mapped to CRF by the argument builder).
  final Quality quality;

  /// Whether the frame cache may serve frames captured by an earlier run
  /// with the same render digest.
  final bool cacheEnabled;

  /// A copy with the given fields replaced (re-validated on construction).
  RenderConfig copyWith({
    int? width,
    int? height,
    int? fps,
    int? frameCount,
    int? startFrame,
    Quality? quality,
    bool? cacheEnabled,
  }) => RenderConfig(
    width: width ?? this.width,
    height: height ?? this.height,
    fps: fps ?? this.fps,
    frameCount: frameCount ?? this.frameCount,
    startFrame: startFrame ?? this.startFrame,
    quality: quality ?? this.quality,
    cacheEnabled: cacheEnabled ?? this.cacheEnabled,
  );

  /// The JSON form (stable field order; [Quality] by name).
  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'fps': fps,
    'frameCount': frameCount,
    'startFrame': startFrame,
    'quality': quality.name,
    'cacheEnabled': cacheEnabled,
  };

  @override
  bool operator ==(Object other) =>
      other is RenderConfig &&
      other.width == width &&
      other.height == height &&
      other.fps == fps &&
      other.frameCount == frameCount &&
      other.startFrame == startFrame &&
      other.quality == quality &&
      other.cacheEnabled == cacheEnabled;

  @override
  int get hashCode =>
      Object.hash(width, height, fps, frameCount, startFrame, quality, cacheEnabled);

  @override
  String toString() =>
      'RenderConfig(${width}x$height@$fps, frames $startFrame..'
      '${startFrame + frameCount - 1}, $quality, cache: $cacheEnabled)';
}
