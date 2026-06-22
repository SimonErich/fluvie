/// The platform byte reader for `file://` media sources.
///
/// Resolves to a real `dart:io` read on native platforms and to a typed
/// "not supported on web" failure in the browser, so a single
/// `MediaBytesLoader` compiles on every target.
library;

export 'file_bytes_io.dart' if (dart.library.js_interop) 'file_bytes_web.dart';
