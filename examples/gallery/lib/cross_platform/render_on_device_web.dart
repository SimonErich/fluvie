import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

/// Renders [video] to MP4 bytes with ffmpeg.wasm, in the browser.
///
/// The same `Video` the mobile path renders; here ffmpeg.wasm encodes on the
/// page and returns the bytes directly. Audio is mixed by the shared `amix` plan.
/// The render parameters match the mobile path one-for-one.
Future<Uint8List> renderOnDevice(
  Video video, {
  Aspect aspect = Aspect.square,
  Duration duration = const Duration(seconds: 2),
  int fps = 30,
  int longEdge = 480,
  bool audio = true,
  RenderProgressCallback? onProgress,
  NetworkAllowlist? networkAllowlist,
}) => WebVideoRenderer(networkAllowlist: networkAllowlist).render(
  composition: video,
  aspect: aspect,
  duration: duration,
  fps: fps,
  longEdge: longEdge,
  audio: audio,
  onProgress: onProgress,
);
