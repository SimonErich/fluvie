/// Picks the on-device renderer for the platform the app is built for: the native
/// mobile encoder on Android and iOS, ffmpeg.wasm in the browser.
///
/// The caller passes the same `Video` (audio and all); only the import resolves
/// per platform, so one app renders on-device everywhere.
library;

// #docregion conditional-export
export 'render_on_device_stub.dart'
    if (dart.library.io) 'render_on_device_mobile.dart'
    if (dart.library.js_interop) 'render_on_device_web.dart';

// #enddocregion conditional-export
