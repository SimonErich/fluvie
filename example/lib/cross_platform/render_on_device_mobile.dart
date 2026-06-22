import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

/// Renders [video] to MP4 bytes with the native mobile encoder (Android/iOS).
///
/// The same `Video` the web path renders; here the platform's hardware encoder
/// writes the file, which is read back to bytes. Audio is mixed and muxed
/// natively. The render parameters match the web path one-for-one.
Future<Uint8List> renderOnDevice(
  Video video, {
  Aspect aspect = Aspect.square,
  Duration duration = const Duration(seconds: 2),
  int fps = 30,
  int longEdge = 480,
  bool audio = true,
  RenderProgressCallback? onProgress,
  NetworkAllowlist? networkAllowlist,
}) async {
  final file = await OnDeviceVideoRenderer(networkAllowlist: networkAllowlist).render(
    composition: video,
    aspect: aspect,
    duration: duration,
    fps: fps,
    longEdge: longEdge,
    audio: audio,
    onProgress: onProgress,
  );
  return file.readAsBytes();
}
