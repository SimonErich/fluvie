/// @docImport 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
library;

/// How the widget tree is being driven right now: a live preview or a
/// deterministic frame capture.
///
/// Widgets read the ambient mode with [RenderModeContext.modeOf] and disable
/// anything that breaks determinism — platform views, implicit animations,
/// mid-frame async — while capturing.
enum RenderMode {
  /// Interactive use: a running app or the inspector. Wall-clock tickers and
  /// platform views are fine; nothing is being encoded.
  preview,

  /// Headless rendering: the frame index is the only clock. Media is
  /// pre-resolved before the frame loop and every build must be a pure
  /// function of the current frame.
  capture,
}
