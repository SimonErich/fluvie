/// The in-browser clip decoder factory.
///
/// Resolves to a real WebCodecs bridge in the browser and to a clear
/// "browser only" failure elsewhere, so `createWebClipDecoder` is importable
/// everywhere (tests, analysis, the VM).
library;

export 'clip_decoder_stub.dart' if (dart.library.js_interop) 'clip_decoder_web.dart';
