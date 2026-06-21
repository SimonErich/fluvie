import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// The web plugin registration entry point.
///
/// The encoder is pure Dart driving the page's ffmpeg.wasm bridge, so there is
/// no platform channel to register — this exists so Flutter recognizes the
/// package as a web plugin and bundles its assets only when an app depends on it.
class FluvieWebEncoderPlugin {
  /// Registers the plugin (a no-op by design).
  static void registerWith(Registrar registrar) {}
}
