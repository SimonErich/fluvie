import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../exceptions/fluvie_exceptions.dart';
import '../utils/logger.dart';

class FrameSequencer {
  final GlobalKey repaintBoundaryKey;

  FrameSequencer(this.repaintBoundaryKey);

  Future<ui.Image> captureFrame({double pixelRatio = 3.0}) async {
    final boundary = await _resolveBoundary();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    return image;
  }

  /// Captures a frame with exact target dimensions.
  ///
  /// This method ensures the output exactly matches [targetWidth] x [targetHeight],
  /// which is critical for rawvideo encoding where FFmpeg expects exact byte counts.
  ///
  /// If the captured image doesn't match the target dimensions, it will be
  /// resized to fit.
  Future<Uint8List> captureFrameRawExact({
    required double pixelRatio,
    required int targetWidth,
    required int targetHeight,
    ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
  }) async {
    final boundary = await _resolveBoundary();
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    try {
      // Check if dimensions match
      if (image.width == targetWidth && image.height == targetHeight) {
        // Perfect match - return directly
        final byteData = await image.toByteData(format: format);
        if (byteData == null) {
          throw FrameCaptureException(
            'Failed to convert frame to raw bytes',
            boundaryKey: repaintBoundaryKey.toString(),
          );
        }
        // Use view directly to avoid extra copy
        return byteData.buffer.asUint8List();
      }

      // Dimensions don't match - need to resize
      FluvieLogger.debug(
        'Resizing frame from ${image.width}x${image.height} to ${targetWidth}x$targetHeight',
        module: 'capture',
      );

      // Create a picture recorder to draw the scaled image
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Calculate scale to fit
      final scaleX = targetWidth / image.width;
      final scaleY = targetHeight / image.height;

      // Use uniform scale to maintain aspect ratio and center
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final scaledWidth = image.width * scale;
      final scaledHeight = image.height * scale;
      final offsetX = (targetWidth - scaledWidth) / 2;
      final offsetY = (targetHeight - scaledHeight) / 2;

      // Fill with black background (in case of aspect ratio mismatch)
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF000000),
      );

      // Draw scaled image centered
      canvas.save();
      canvas.translate(offsetX, offsetY);
      canvas.scale(scale, scale);
      canvas.drawImage(
        image,
        ui.Offset.zero,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(targetWidth, targetHeight);
      picture.dispose();

      try {
        final byteData = await resizedImage.toByteData(format: format);
        if (byteData == null) {
          throw FrameCaptureException(
            'Failed to convert resized frame to raw bytes',
            boundaryKey: repaintBoundaryKey.toString(),
          );
        }
        // Use view directly to avoid extra copy
        return byteData.buffer.asUint8List();
      } finally {
        resizedImage.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> captureFrameRaw({
    required double pixelRatio,
    ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
  }) async {
    final boundary = await _resolveBoundary();
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    try {
      // Log actual captured dimensions for debugging
      FluvieLogger.debug(
        'Captured frame at ${image.width}x${image.height}',
        module: 'capture',
      );

      // Capture frame bytes in the specified format.
      //
      // Use rawRgba for fastest capture (no encoding overhead).
      // Use png when transparency is needed in the output.
      //
      // Important: For correct video rendering, the composition should use
      // fade-aware widgets (FadeText, FadeContainer, etc.) with the Fade widget
      // instead of Flutter's Opacity widget. This avoids saveLayer() calls
      // which create intermediate buffers with transparent backgrounds that
      // cause black rectangle artifacts in the rendered video.
      final byteData = await image.toByteData(format: format);
      if (byteData == null) {
        throw FrameCaptureException(
          'Failed to convert frame to raw bytes',
          boundaryKey: repaintBoundaryKey.toString(),
        );
      }
      // Use view directly to avoid extra copy
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<RenderRepaintBoundary> _resolveBoundary() async {
    final RenderRepaintBoundary? boundary = repaintBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      FluvieLogger.error('RepaintBoundary not found!', module: 'capture');
      throw FrameCaptureException(
        'RepaintBoundary not found. Ensure your composition widget tree has a RepaintBoundary with the correct GlobalKey.',
        boundaryKey: repaintBoundaryKey.toString(),
      );
    }

    if (boundary.debugNeedsPaint) {
      // This might happen if the frame hasn't been rasterized yet.
      // In a real isolate loop, we would ensure the frame is built.
      // For now, we assume the widget tree is built.
      // We might need to wait for end of frame.
      FluvieLogger.debug('Boundary needs paint, waiting...', module: 'capture');
      await Future.delayed(Duration.zero);
      FluvieLogger.debug('Paint wait completed', module: 'capture');
    }

    return boundary;
  }
}
