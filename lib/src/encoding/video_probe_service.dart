import 'dart:convert';
import 'dart:io';

import '../config/fluvie_config.dart';
import '../exceptions/fluvie_exceptions.dart';

/// Probes video files for metadata using ffprobe.
///
/// This service extracts detailed information about video files including
/// dimensions, frame rate, duration, and audio stream presence.
///
/// Example:
/// ```dart
/// final service = VideoProbeService();
/// final metadata = await service.probe('assets/video.mp4');
/// print('Duration: ${metadata.duration}');
/// print('FPS: ${metadata.fps}');
/// print('Has audio: ${metadata.hasAudio}');
/// ```
class VideoProbeService {
  /// Custom path to the ffprobe executable.
  ///
  /// If null, uses the configured ffprobe path or falls back to 'ffprobe'.
  final String? ffprobePath;

  /// Creates a new VideoProbeService.
  ///
  /// [ffprobePath] - Custom path to ffprobe executable. If null, uses
  /// the configured path or 'ffprobe' from PATH.
  VideoProbeService({this.ffprobePath});

  /// Gets the effective ffprobe executable path.
  String get _ffprobeExecutable =>
      ffprobePath ?? FluvieConfig.current.ffprobePath ?? 'ffprobe';

  /// Checks if ffprobe is available on the system.
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(_ffprobeExecutable, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Probes a video file and returns its metadata.
  ///
  /// Throws [VideoProbeException] if the file cannot be probed.
  Future<VideoMetadata> probe(String videoPath) async {
    final available = await isAvailable();
    if (!available) {
      throw VideoProbeException(
        'ffprobe executable not found',
        details: 'Install FFmpeg to enable video probing',
      );
    }

    // Check if file exists
    final file = File(videoPath);
    if (!file.existsSync()) {
      throw VideoProbeException(
        'Video file not found',
        details: 'Path: $videoPath',
      );
    }

    try {
      final result = await Process.run(_ffprobeExecutable, [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        videoPath,
      ]);

      if (result.exitCode != 0) {
        throw VideoProbeException(
          'ffprobe failed',
          details: result.stderr.toString(),
        );
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return _parseMetadata(json);
    } catch (e) {
      if (e is VideoProbeException) rethrow;
      throw VideoProbeException('Failed to probe video', details: e.toString());
    }
  }

  /// Parses ffprobe JSON output into VideoMetadata.
  VideoMetadata _parseMetadata(Map<String, dynamic> json) {
    final streams = json['streams'] as List<dynamic>? ?? [];
    final format = json['format'] as Map<String, dynamic>? ?? {};

    // Find video stream
    Map<String, dynamic>? videoStream;
    Map<String, dynamic>? audioStream;

    for (final stream in streams) {
      final codecType = stream['codec_type'] as String?;
      if (codecType == 'video' && videoStream == null) {
        videoStream = stream as Map<String, dynamic>;
      } else if (codecType == 'audio' && audioStream == null) {
        audioStream = stream as Map<String, dynamic>;
      }
    }

    if (videoStream == null) {
      throw VideoProbeException(
        'No video stream found',
        details: 'The file does not contain a video stream',
      );
    }

    // Parse dimensions
    final width = videoStream['width'] as int? ?? 0;
    final height = videoStream['height'] as int? ?? 0;

    // Parse frame rate (format: "30/1" or "30000/1001")
    final fps = _parseFrameRate(videoStream['r_frame_rate'] as String?);

    // Parse duration (prefer stream duration, fallback to format duration)
    final duration = _parseDuration(
      videoStream['duration'] as String?,
      format['duration'] as String?,
    );

    // Calculate frame count
    int frameCount;
    final nbFrames = videoStream['nb_frames'] as String?;
    if (nbFrames != null) {
      frameCount = int.tryParse(nbFrames) ?? 0;
    } else {
      // Calculate from duration and fps
      frameCount = (duration.inMicroseconds * fps / 1000000).round();
    }

    // Parse audio stream info
    final hasAudio = audioStream != null;
    final audioCodec = audioStream?['codec_name'] as String?;
    final audioBitrate = _parseBitrate(audioStream?['bit_rate'] as String?);
    final audioChannels = audioStream?['channels'] as int?;
    final audioSampleRate = int.tryParse(
      audioStream?['sample_rate'] as String? ?? '',
    );

    return VideoMetadata(
      width: width,
      height: height,
      fps: fps,
      duration: duration,
      frameCount: frameCount,
      hasAudio: hasAudio,
      audioCodec: audioCodec,
      audioBitrate: audioBitrate,
      audioChannels: audioChannels,
      audioSampleRate: audioSampleRate,
      videoCodec: videoStream['codec_name'] as String?,
      bitrate: _parseBitrate(format['bit_rate'] as String?),
    );
  }

  /// Parses frame rate string like "30/1" or "30000/1001".
  double _parseFrameRate(String? frameRateStr) {
    if (frameRateStr == null || frameRateStr.isEmpty) {
      return 30.0; // Default fallback
    }

    final parts = frameRateStr.split('/');
    if (parts.length == 2) {
      final numerator = double.tryParse(parts[0]) ?? 30;
      final denominator = double.tryParse(parts[1]) ?? 1;
      if (denominator > 0) {
        return numerator / denominator;
      }
    }

    return double.tryParse(frameRateStr) ?? 30.0;
  }

  /// Parses duration from stream or format.
  Duration _parseDuration(String? streamDuration, String? formatDuration) {
    final durationStr = streamDuration ?? formatDuration;
    if (durationStr == null || durationStr.isEmpty) {
      return Duration.zero;
    }

    final seconds = double.tryParse(durationStr) ?? 0;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  /// Parses bitrate string to integer.
  int? _parseBitrate(String? bitrateStr) {
    if (bitrateStr == null || bitrateStr.isEmpty) return null;
    return int.tryParse(bitrateStr);
  }
}

/// Video file metadata extracted via ffprobe.
class VideoMetadata {
  /// Video width in pixels.
  final int width;

  /// Video height in pixels.
  final int height;

  /// Frame rate (frames per second).
  final double fps;

  /// Total duration of the video.
  final Duration duration;

  /// Total number of frames in the video.
  final int frameCount;

  /// Whether the video has an audio stream.
  final bool hasAudio;

  /// Audio codec name (e.g., 'aac', 'mp3').
  final String? audioCodec;

  /// Audio bitrate in bits per second.
  final int? audioBitrate;

  /// Number of audio channels.
  final int? audioChannels;

  /// Audio sample rate in Hz.
  final int? audioSampleRate;

  /// Video codec name (e.g., 'h264', 'hevc').
  final String? videoCodec;

  /// Overall bitrate in bits per second.
  final int? bitrate;

  const VideoMetadata({
    required this.width,
    required this.height,
    required this.fps,
    required this.duration,
    required this.frameCount,
    required this.hasAudio,
    this.audioCodec,
    this.audioBitrate,
    this.audioChannels,
    this.audioSampleRate,
    this.videoCodec,
    this.bitrate,
  });

  /// Returns the aspect ratio of the video.
  double get aspectRatio => width > 0 && height > 0 ? width / height : 1.0;

  /// Returns duration in seconds as a double.
  double get durationSeconds => duration.inMicroseconds / 1000000.0;

  @override
  String toString() {
    return 'VideoMetadata('
        'width: $width, '
        'height: $height, '
        'fps: ${fps.toStringAsFixed(2)}, '
        'duration: ${durationSeconds.toStringAsFixed(2)}s, '
        'frames: $frameCount, '
        'hasAudio: $hasAudio'
        ')';
  }
}

// VideoProbeException is now defined in fluvie_exceptions.dart and imported above
