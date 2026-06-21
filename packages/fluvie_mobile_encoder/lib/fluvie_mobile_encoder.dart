/// Render Fluvie videos to MP4 fully on-device on Android and iOS.
///
/// Import this single barrel:
///
/// ```dart
/// import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
/// ```
///
/// The capture half is Fluvie's own deterministic pipeline; this package swaps
/// the FFmpeg encode step for the platform's native hardware encoder, so the
/// frames never leave the device. `src/` stays private.
library;

export 'src/capture_host.dart';
export 'src/fake_mobile_video_encoder.dart';
export 'src/fluvie_mobile_encoder_exception.dart';
export 'src/method_channel_mobile_video_encoder.dart';
export 'src/mobile_audio_materializer.dart';
export 'src/mobile_audio_track.dart';
export 'src/mobile_bitrate.dart';
export 'src/mobile_encode_request.dart';
export 'src/mobile_encoder_providers.dart';
export 'src/mobile_video_codec.dart';
export 'src/mobile_video_encoder.dart';
export 'src/network_audio_materializer.dart' show MobileAudioFetch, NetworkAudioMaterializer;
export 'src/offscreen_capture_host.dart';
export 'src/on_device_render_progress.dart';
export 'src/on_device_video_renderer.dart';
