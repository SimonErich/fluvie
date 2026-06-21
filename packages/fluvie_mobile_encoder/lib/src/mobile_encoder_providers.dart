import 'package:fluvie_mobile_encoder/src/method_channel_mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/on_device_video_renderer.dart';
import 'package:riverpod/riverpod.dart';

/// The on-device video encoder.
///
/// Defaults to the platform method-channel encoder; override it with a
/// `FakeMobileVideoEncoder` in tests, or with another [MobileVideoEncoder] to
/// swap the backend.
final mobileVideoEncoderProvider = Provider<MobileVideoEncoder>(
  (ref) => const MethodChannelMobileVideoEncoder(),
);

/// The on-device renderer, wired to [mobileVideoEncoderProvider].
///
/// Override the encoder provider (or this provider directly) in tests; the
/// renderer's other seams default to the real device host and a temp sandbox.
final onDeviceVideoRendererProvider = Provider<OnDeviceVideoRenderer>(
  (ref) => OnDeviceVideoRenderer(encoder: ref.watch(mobileVideoEncoderProvider)),
);
