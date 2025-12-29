import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/fluvie_config.dart';

/// Extracts frames from video files using FFmpeg.
///
/// This service provides high-quality frame extraction with support for
/// single frames, frame ranges, and streaming extraction for buffering.
///
/// Example:
/// ```dart
/// final service = FrameExtractionService();
///
/// // Extract single frame
/// final frame = await service.extractFrame(
///   videoPath: 'video.mp4',
///   timestamp: Duration(seconds: 2),
///   width: 800,
///   height: 450,
/// );
///
/// // Extract range for buffering
/// final frames = await service.extractFrameRange(
///   videoPath: 'video.mp4',
///   startFrame: 0,
///   endFrame: 30,
///   sourceFps: 30.0,
///   width: 800,
///   height: 450,
/// );
/// ```
class FrameExtractionService {
  /// Custom path to the FFmpeg executable.
  final String? ffmpegPath;

  /// Creates a new FrameExtractionService.
  FrameExtractionService({this.ffmpegPath});

  /// Gets the effective FFmpeg executable path.
  String get _ffmpegExecutable =>
      ffmpegPath ?? FluvieConfig.current.ffmpegPath ?? 'ffmpeg';

  /// Checks if FFmpeg is available on the system.
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(_ffmpegExecutable, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Extracts a single frame at the specified timestamp.
  ///
  /// Returns raw RGBA pixel data for the frame.
  ///
  /// [videoPath] - Path to the video file.
  /// [timestamp] - Time position to extract the frame from.
  /// [width] - Target width of the extracted frame.
  /// [height] - Target height of the extracted frame.
  /// [fit] - How to fit the video within the target dimensions.
  Future<ExtractedFrame> extractFrame({
    required String videoPath,
    required Duration timestamp,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    final timestampSeconds = timestamp.inMicroseconds / 1000000.0;

    // Build scale filter based on BoxFit
    final scaleFilter = _buildScaleFilter(width, height, fit);

    final args = <String>[
      '-ss',
      timestampSeconds.toStringAsFixed(6),
      '-i',
      videoPath,
      '-vf',
      scaleFilter,
      '-frames:v',
      '1',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-',
    ];

    final process = await Process.start(_ffmpegExecutable, args);

    final outputBytes = <int>[];
    final errorBuffer = StringBuffer();

    // Collect stdout (frame data)
    await for (final chunk in process.stdout) {
      outputBytes.addAll(chunk);
    }

    // Collect stderr (errors/info)
    await for (final chunk in process.stderr) {
      errorBuffer.write(String.fromCharCodes(chunk));
    }

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw FrameExtractionException(
        'Failed to extract frame',
        details: errorBuffer.toString(),
      );
    }

    final expectedSize = width * height * 4;
    if (outputBytes.length != expectedSize) {
      throw FrameExtractionException(
        'Invalid frame size',
        details:
            'Expected $expectedSize bytes, got ${outputBytes.length} bytes',
      );
    }

    return ExtractedFrame(
      frameNumber: (timestamp.inMicroseconds * 30 / 1000000).round(),
      rgba: Uint8List.fromList(outputBytes),
      width: width,
      height: height,
    );
  }

  /// Extracts a frame at the specified source frame number.
  ///
  /// This method calculates the timestamp from the frame number and source FPS.
  Future<ExtractedFrame> extractFrameByNumber({
    required String videoPath,
    required int frameNumber,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    final timestamp = Duration(
      microseconds: (frameNumber * 1000000 / sourceFps).round(),
    );
    final frame = await extractFrame(
      videoPath: videoPath,
      timestamp: timestamp,
      width: width,
      height: height,
      fit: fit,
    );
    return ExtractedFrame(
      frameNumber: frameNumber,
      rgba: frame.rgba,
      width: width,
      height: height,
    );
  }

  /// Extracts a range of frames for efficient buffering.
  ///
  /// This is more efficient than extracting frames one by one when
  /// you need multiple consecutive frames.
  ///
  /// [startFrame] and [endFrame] are inclusive.
  Future<List<ExtractedFrame>> extractFrameRange({
    required String videoPath,
    required int startFrame,
    required int endFrame,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    if (endFrame < startFrame) {
      throw ArgumentError('endFrame must be >= startFrame');
    }

    final frameCount = endFrame - startFrame + 1;
    final startTimestamp = startFrame / sourceFps;

    // Build scale filter based on BoxFit
    final scaleFilter = _buildScaleFilter(width, height, fit);

    final args = <String>[
      '-ss',
      startTimestamp.toStringAsFixed(6),
      '-i',
      videoPath,
      '-vf',
      scaleFilter,
      '-frames:v',
      '$frameCount',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-vsync',
      '0',
      '-',
    ];

    final process = await Process.start(_ffmpegExecutable, args);

    final outputBytes = <int>[];
    final errorBuffer = StringBuffer();

    await for (final chunk in process.stdout) {
      outputBytes.addAll(chunk);
    }

    await for (final chunk in process.stderr) {
      errorBuffer.write(String.fromCharCodes(chunk));
    }

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw FrameExtractionException(
        'Failed to extract frame range',
        details: errorBuffer.toString(),
      );
    }

    final frameSize = width * height * 4;
    final extractedFrameCount = outputBytes.length ~/ frameSize;

    final frames = <ExtractedFrame>[];
    for (int i = 0; i < extractedFrameCount; i++) {
      final start = i * frameSize;
      final end = start + frameSize;
      frames.add(
        ExtractedFrame(
          frameNumber: startFrame + i,
          rgba: Uint8List.fromList(outputBytes.sublist(start, end)),
          width: width,
          height: height,
        ),
      );
    }

    return frames;
  }

  /// Streams frames for efficient background preloading.
  ///
  /// This method returns a stream of extracted frames, allowing
  /// for efficient buffering without blocking.
  Stream<ExtractedFrame> extractFrameStream({
    required String videoPath,
    required int startFrame,
    required double sourceFps,
    required int width,
    required int height,
    int frameCount = 30,
    BoxFit fit = BoxFit.cover,
  }) async* {
    final startTimestamp = startFrame / sourceFps;
    final scaleFilter = _buildScaleFilter(width, height, fit);

    final args = <String>[
      '-ss',
      startTimestamp.toStringAsFixed(6),
      '-i',
      videoPath,
      '-vf',
      scaleFilter,
      '-frames:v',
      '$frameCount',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-vsync',
      '0',
      '-',
    ];

    final process = await Process.start(_ffmpegExecutable, args);

    final frameSize = width * height * 4;
    final buffer = <int>[];
    int currentFrame = startFrame;

    await for (final chunk in process.stdout) {
      buffer.addAll(chunk);

      // Yield complete frames as they become available
      while (buffer.length >= frameSize) {
        final frameData = Uint8List.fromList(buffer.sublist(0, frameSize));
        buffer.removeRange(0, frameSize);

        yield ExtractedFrame(
          frameNumber: currentFrame,
          rgba: frameData,
          width: width,
          height: height,
        );
        currentFrame++;
      }
    }

    await process.exitCode;
  }

  /// Builds a scale filter string based on BoxFit.
  String _buildScaleFilter(int width, int height, BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        // Scale to fit within bounds, maintaining aspect ratio
        return 'scale=$width:$height:force_original_aspect_ratio=decrease,'
            'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black,'
            'format=rgba';

      case BoxFit.cover:
        // Scale to cover bounds, may crop
        return 'scale=$width:$height:force_original_aspect_ratio=increase,'
            'crop=$width:$height,'
            'format=rgba';

      case BoxFit.fill:
        // Stretch to fill (distorts aspect ratio)
        return 'scale=$width:$height:flags=lanczos,'
            'format=rgba';

      case BoxFit.fitWidth:
        // Fit width, may be taller or shorter
        return 'scale=$width:-1:flags=lanczos,'
            'crop=$width:$height:(iw-ow)/2:(ih-oh)/2,'
            'format=rgba';

      case BoxFit.fitHeight:
        // Fit height, may be wider or narrower
        return 'scale=-1:$height:flags=lanczos,'
            'crop=$width:$height:(iw-ow)/2:(ih-oh)/2,'
            'format=rgba';

      case BoxFit.none:
        // No scaling, center crop
        return 'crop=$width:$height:(iw-$width)/2:(ih-$height)/2,'
            'format=rgba';

      case BoxFit.scaleDown:
        // Like contain but only scales down, never up
        return 'scale=\'min($width,iw)\':\'min($height,ih)\':force_original_aspect_ratio=decrease,'
            'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black,'
            'format=rgba';
    }
  }
}

/// Represents an extracted video frame.
class ExtractedFrame {
  /// Frame number in the source video.
  final int frameNumber;

  /// Raw RGBA pixel data.
  final Uint8List rgba;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  ExtractedFrame({
    required this.frameNumber,
    required this.rgba,
    required this.width,
    required this.height,
  });

  /// Size of the frame data in bytes.
  int get sizeInBytes => rgba.length;

  /// Converts the raw RGBA data to a Flutter ui.Image.
  ///
  /// This is an expensive operation and should be called sparingly.
  Future<ui.Image> toImage() async {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, (
      ui.Image image,
    ) {
      completer.complete(image);
    });

    return completer.future;
  }

  /// Creates a MemoryImage provider from this frame.
  ///
  /// Note: This converts RGBA to a format suitable for ImageProvider.
  /// For best performance, use [toImage] directly when possible.
  Future<MemoryImage> toImageProvider() async {
    final image = await toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw FrameExtractionException('Failed to convert frame to PNG');
    }

    return MemoryImage(byteData.buffer.asUint8List());
  }
}

/// Exception thrown when frame extraction fails.
class FrameExtractionException implements Exception {
  /// Error message.
  final String message;

  /// Additional details about the error.
  final String? details;

  FrameExtractionException(this.message, {this.details});

  @override
  String toString() {
    if (details != null) {
      return 'FrameExtractionException: $message\nDetails: $details';
    }
    return 'FrameExtractionException: $message';
  }
}
