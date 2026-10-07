/// The capture surface the in-browser renderer needs, as a root wrapper.
///
/// In-browser capture reads pixels back from a boundary painted by the app's
/// own pipeline, so the web build wraps its root in a `FluvieWebStage`
/// (off-screen, never visible). Everywhere else the app passes through
/// unchanged — the desktop renders through its own off-screen pipeline.
library;

export 'render_stage_io.dart' if (dart.library.js_interop) 'render_stage_web.dart';
