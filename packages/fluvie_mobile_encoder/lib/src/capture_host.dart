import 'package:flutter/widgets.dart';

/// Drives one off-screen render surface for the on-device capture loop.
///
/// Fluvie's `render` builds a capture shell and asks a host to mount it and pump
/// it one frame at a time. On a device the default host, `OffscreenCaptureHost`,
/// renders into its own pipeline sized to the target resolution, so nothing
/// flickers on screen; tests inject a host backed by the widget tester.
abstract interface class CaptureHost {
  /// Mounts [tree] into the off-screen render surface.
  Future<void> mount(Widget tree);

  /// Builds and paints the next frame so its pixels can be read back.
  Future<void> pumpFrame();

  /// Tears the surface down and releases its resources.
  Future<void> dispose();
}
