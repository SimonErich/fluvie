/// The honest web-export capability probe: whether the page installed the
/// `FluvieFfmpeg` bridge the in-browser encoder drives.
///
/// Resolves to a real page-global check in the browser and to a constant
/// `false` elsewhere, so the export menu never shows a dead button — a page
/// without the bridge gets a disabled entry that says what is missing.
library;

export 'web_export_capability_stub.dart'
    if (dart.library.js_interop) 'web_export_capability_web.dart';
