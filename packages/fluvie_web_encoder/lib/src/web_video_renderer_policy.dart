part of 'web_video_renderer.dart';

// coverage:ignore-line the default sink runs only when no onWarning is injected which tests always do
void _defaultWarn(String message) => debugPrint('fluvie_web_encoder: $message');

// coverage:ignore-line binds to the live FluvieWebStage exercised only in a browser
WebCaptureHost _defaultHostFactory(Size size) => FluvieWebStage.hostFor(size);

// coverage:ignore-line constructs the default ffmpeg wasm encoder only valid in a browser
WebVideoEncoder _defaultEncoder() => WebVideoEncoder();
