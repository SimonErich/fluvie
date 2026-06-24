/// The Playground's rendered-video area, resolved per platform.
///
/// On web (`dart.library.js_interop`) it embeds an HTML `<video controls>`; on
/// the VM and in tests it is a placeholder that never pulls in `dart:ui_web` or
/// `package:web`. Both expose the same `PlaygroundVideo({required String? url})`.
library;

export 'playground_video_stub.dart' if (dart.library.js_interop) 'playground_video_web.dart';
