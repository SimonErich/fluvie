import 'package:fluvie_mobile_encoder/src/mobile_audio_track.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_codec.dart';
import 'package:meta/meta.dart';

/// One on-device encode: the raw RGBA frames file to read and the MP4 to write.
///
/// [framesPath] points at the `frames.rgba` file Fluvie's capture loop produced
/// — [frameCount] frames of `width * height * 4` RGBA8888 bytes, row-major, with
/// no padding. The platform encoder reads it sequentially and writes
/// [outputPath]. Presentation timestamps are derived from each frame's index and
/// [fps], so the encode carries no wall-clock. [audioTracks] (empty for a silent
/// render) are decoded, mixed at [audioMasterVolume], and muxed as the audio
/// track.
@immutable
final class MobileEncodeRequest {
  /// Creates a validated encode request.
  ///
  /// Throws an [ArgumentError] when a dimension is not positive and even, when
  /// [fps], [frameCount], or [bitRate] are not positive, or when a path is
  /// empty.
  MobileEncodeRequest({
    required this.framesPath,
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.bitRate,
    this.codec = MobileVideoCodec.h264,
    this.audioTracks = const <MobileAudioTrack>[],
    this.audioMasterVolume = 1,
  }) {
    _nonEmpty(framesPath, 'framesPath');
    _nonEmpty(outputPath, 'outputPath');
    _positiveEven(width, 'width');
    _positiveEven(height, 'height');
    _positive(fps, 'fps');
    _positive(frameCount, 'frameCount');
    _positive(bitRate, 'bitRate');
  }

  /// Absolute path of the raw RGBA8888 frames file to read.
  final String framesPath;

  /// Absolute path of the MP4 file to write.
  final String outputPath;

  /// Output width in pixels (positive and even).
  final int width;

  /// Output height in pixels (positive and even).
  final int height;

  /// Frames per second of the output video.
  final int fps;

  /// How many frames [framesPath] holds.
  final int frameCount;

  /// Target average bitrate in bits per second.
  final int bitRate;

  /// The codec the platform encoder should use.
  final MobileVideoCodec codec;

  /// The audio tracks to decode, mix, and mux; empty for a silent render.
  final List<MobileAudioTrack> audioTracks;

  /// The final gain applied after mixing [audioTracks] together.
  final double audioMasterVolume;

  /// The argument map handed to the platform method channel.
  Map<String, Object?> toArguments() => {
    'framesPath': framesPath,
    'outputPath': outputPath,
    'width': width,
    'height': height,
    'fps': fps,
    'frameCount': frameCount,
    'bitRate': bitRate,
    'codec': codec.wireName,
    'audioMasterVolume': audioMasterVolume,
    'audioTracks': [for (final track in audioTracks) track.toArguments()],
  };

  static void _positive(int value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name, 'must be positive');
  }

  static void _positiveEven(int value, String name) {
    if (value <= 0 || value.isOdd) {
      throw ArgumentError.value(value, name, 'must be positive and even (yuv420p output)');
    }
  }

  static void _nonEmpty(String value, String name) {
    if (value.isEmpty) throw ArgumentError.value(value, name, 'must not be empty');
  }
}
