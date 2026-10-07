import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// coverage:ignore-start browser only probe of the page global bridge object

/// Whether the page installed the `FluvieFfmpeg` bridge (the ffmpeg.wasm
/// wrapper `web/index.html` ships) the in-browser encoder drives.
bool hasFfmpegBridge() => globalContext.has('FluvieFfmpeg');

// coverage:ignore-end
