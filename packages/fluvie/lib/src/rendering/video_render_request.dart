import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/encoder_options.dart';
import 'package:fluvie/src/core/errors/fluvie_capability_exception.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_progress.dart';
import 'package:fluvie_media/fluvie_media.dart' show RenderCapabilities;

part 'video_render_request_validation.dart';

/// The complete, backend-independent request received by a render adapter.
///
/// Canvas pixels and capture range remain explicit, including nonstandard
/// dimensions. [startFrame] selects an authored frame; [frameCount] selects how
/// many pictures to capture without shortening the composition's timing scopes.
final class VideoRenderRequest {
  /// Creates a request and validates its canvas, clock and capture range.
  VideoRenderRequest({
    required this.composition,
    required this.width,
    required this.height,
    required this.frameCount,
    this.fps = VideoDefaults.fps,
    this.startFrame = 0,
    this.aspect,
    this.quality,
    this.export,
    this.posterFrame,
    this.audio = true,
    this.warnOnDroppedAudio = true,
    this.compositionKey = 'render',
    this.onProgress,
    this.cancellation,
  }) {
    config;
    export?.validate();
    if (posterFrame != null && (posterFrame! < 0 || posterFrame! >= frameCount)) {
      throw ArgumentError.value(posterFrame, 'posterFrame', 'must be inside the captured output');
    }
  }

  /// The ordinary Flutter composition mounted by the capture host.
  final Widget composition;

  /// Exact output width in pixels.
  final int width;

  /// Exact output height in pixels.
  final int height;

  /// Output pictures per second.
  final int fps;

  /// Number of pictures to capture from the authored timeline.
  final int frameCount;

  /// First authored frame to capture.
  final int startFrame;

  /// Optional layout branch selected by an adaptive render.
  final Aspect? aspect;

  /// Explicit quality override; otherwise the export's quality is used.
  final Quality? quality;

  /// Explicit output override; otherwise mounted authored settings are used.
  final Export? export;

  /// Poster picture in output frame space, independent of [startFrame].
  final int? posterFrame;

  /// Whether authored tracks and embedded clip audio join the output.
  final bool audio;

  /// Whether intentionally dropped audio produces a warning.
  final bool warnOnDroppedAudio;

  /// Stable composition identity used by progress and cache owners.
  final String compositionKey;

  /// Progress sink owned by the caller.
  final RenderProgressCallback? onProgress;

  /// Cooperative cancellation checked throughout preparation and capture.
  final RenderCancellation? cancellation;

  /// Validated capture settings shared by all backends.
  RenderConfig get config => RenderConfig(
    width: width,
    height: height,
    fps: fps,
    frameCount: frameCount,
    startFrame: startFrame,
    quality: quality ?? export?.quality ?? Quality.high,
    cacheEnabled: false,
  );

  /// Resolves mounted authored options while preserving explicit overrides.
  VideoRenderRequest withAuthoredOptions({Export? authoredExport, int? authoredPosterFrame}) =>
      VideoRenderRequest(
        composition: composition,
        width: width,
        height: height,
        fps: fps,
        frameCount: frameCount,
        startFrame: startFrame,
        aspect: aspect,
        quality: quality,
        export: _resolvedExport(export ?? authoredExport),
        posterFrame: posterFrame ?? authoredPosterFrame,
        audio: audio,
        warnOnDroppedAudio: warnOnDroppedAudio,
        compositionKey: compositionKey,
        onProgress: onProgress,
        cancellation: cancellation,
      );

  Export? _resolvedExport(Export? output) {
    if (output?.mode != ExportMode.mp4 || quality == null) return output;
    return Export.mp4(
      quality: quality!,
      codec: output!.codec,
      crf: output.crf,
      bitRate: output.bitRate,
      preset: output.preset,
      pixelFormat: output.pixelFormat,
    );
  }

  /// Rejects unsupported output choices before capture or encoding starts.
  void validateCapabilities(RenderCapabilities capabilities) => _validateCapabilities(capabilities);
}
