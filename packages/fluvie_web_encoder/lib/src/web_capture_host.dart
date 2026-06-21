import 'package:flutter/widgets.dart';

/// Drives one off-screen render surface for the in-browser capture loop.
///
/// `renderToSandbox` asks a host to mount the capture shell and pump it one
/// frame at a time. The default host (`FluvieWebStage.hostFor`) captures through
/// the app's own pipeline, off-screen; tests inject a host backed by the widget
/// tester.
abstract interface class WebCaptureHost {
  /// Mounts [tree] into the off-screen render surface.
  Future<void> mount(Widget tree);

  /// Builds and paints the next frame so its pixels can be read back.
  Future<void> pumpFrame();

  /// Tears the surface down and releases its resources.
  Future<void> dispose();
}
