import 'package:fluvie/src/core/encoder_options.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/render_config.dart';

/// Encoded facts that can be checked independently of the captured stream.
Map<String, Object?> renderOutputIntent(
  RenderConfig config,
  Export? output, {
  required bool hasAudio,
}) {
  final mode = output?.mode ?? ExportMode.mp4;
  final timed = mode == ExportMode.mp4 || mode == ExportMode.transparent;
  return {
    'width': config.width, 'height': config.height,
    if (mode != ExportMode.gif) 'frameCount': config.frameCount,
    if (timed) ...{
      'fps': config.fps.toDouble(),
      'durationSeconds': config.frameCount / config.fps,
    },
    'codec': switch (mode) {
      ExportMode.mp4 => output?.codec == ExportCodec.h265 ? 'hevc' : 'h264',
      ExportMode.gif => 'gif',
      ExportMode.imageSequence => 'png',
      ExportMode.transparent => 'vp9',
    },
    'container': switch (mode) {
      ExportMode.mp4 => 'mp4',
      ExportMode.gif => 'gif',
      ExportMode.imageSequence => 'png_sequence',
      ExportMode.transparent => 'webm',
    },
    'hasAudio': mode == ExportMode.mp4 && hasAudio,
    // GIF palette timing and transparency depend on its quantized samples.
    if (mode != ExportMode.gif) 'hasAlpha': mode != ExportMode.mp4,
    if (mode == ExportMode.mp4) 'pixelFormat': output?.pixelFormat.name ?? 'yuv420p',
    if (mode == ExportMode.transparent) 'pixelFormat': 'yuva420p',
  };
}
