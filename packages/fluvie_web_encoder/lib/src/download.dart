/// A browser-download helper for rendered bytes.
///
/// Resolves to a real `package:web` download in the browser and to a clear
/// "browser only" failure elsewhere, so the symbol is importable everywhere.
library;

export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
