/// Render Fluvie videos to MP4 fully in the browser with ffmpeg.wasm.
///
/// Import this single barrel:
///
/// ```dart
/// import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
/// ```
///
/// The capture half is Fluvie's own frame-driven pipeline (`renderToSandbox`);
/// this package adds the in-browser ffmpeg.wasm encode, which runs the exact
/// same argument plan as the desktop and server paths. Clips decode on-device
/// through WebCodecs via `createWebClipDecoder`. It is opt-in, so apps that only
/// render via the API stay free of the wasm payload. `src/` stays private.
library;

export 'package:fluvie/rendering.dart'
    show NetworkAllowlist, RenderPhase, RenderProgress, RenderProgressCallback, VideoRenderer;

export 'src/clip_decoder.dart' show createWebClipDecoder;
export 'src/download.dart' show downloadBytes;
export 'src/fluvie_web_stage.dart' show FluvieWebStage;
export 'src/web_audio_materializer.dart'
    show BundleWebAudioMaterializer, WebAudioFetch, WebAudioMaterializer;
export 'src/web_capture_host.dart';
export 'src/web_video_encoder.dart' show WebVideoEncoder;
export 'src/web_video_renderer.dart';
