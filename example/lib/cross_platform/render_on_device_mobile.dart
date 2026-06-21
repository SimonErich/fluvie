import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

/// Renders [video] to MP4 bytes with the native mobile encoder (Android/iOS).
///
/// The same `Video` the web path renders; here the platform's hardware encoder
/// writes the file, which is read back to bytes. Audio is mixed and muxed
/// natively.
Future<Uint8List> renderOnDevice(Video video) async {
  final file = await OnDeviceVideoRenderer().render(
    composition: video,
    aspect: Aspect.square,
    duration: const Duration(seconds: 2),
    longEdge: 480,
    audio: true,
  );
  return file.readAsBytes();
}
