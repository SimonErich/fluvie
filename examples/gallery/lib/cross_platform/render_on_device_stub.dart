import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

/// The fallback when neither a mobile nor a web build is selected.
///
/// On-device rendering needs `dart:io` (mobile) or `dart:js_interop` (web); a
/// pure-VM build resolves to this and throws.
Future<Uint8List> renderOnDevice(
  Video video, {
  Aspect aspect = Aspect.square,
  Duration duration = const Duration(seconds: 2),
  int fps = 30,
  int longEdge = 480,
  bool audio = true,
  RenderProgressCallback? onProgress,
  NetworkAllowlist? networkAllowlist,
}) => throw UnsupportedError('On-device rendering needs a mobile or web build.');
