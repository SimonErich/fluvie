/// The live-preview widget builder for `file://` image sources.
///
/// Resolves to Flutter's `Image.file` on native platforms and to a typed
/// "not supported on web" failure in the browser, so `resolved_image.dart`
/// compiles everywhere without importing `dart:io` directly.
library;

export 'file_image_io.dart' if (dart.library.js_interop) 'file_image_web.dart';
