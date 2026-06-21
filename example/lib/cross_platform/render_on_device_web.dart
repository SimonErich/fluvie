import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

/// Renders [video] to MP4 bytes with ffmpeg.wasm, in the browser.
///
/// The same `Video` the mobile path renders; here ffmpeg.wasm encodes on the
/// page and returns the bytes directly. Audio is mixed by the shared `amix` plan.
Future<Uint8List> renderOnDevice(Video video) => WebVideoRenderer().render(
  composition: video,
  aspect: Aspect.square,
  duration: const Duration(seconds: 2),
  longEdge: 480,
  audio: true,
);
