import 'package:fluvie_example/inspector/render_launcher.dart'
    show RenderLaunchResult, RenderProgress;
import 'package:fluvie_server/client.dart' show ApiValidationResult;

/// The Playground's backend: statically validate a Dart `Video build()` snippet,
/// then render it to a video.
///
/// Abstract so the widget is testable with a fake and the transport (a
/// `fluvie_server` over HTTP) is swappable. Validation is analysis-only and
/// never executes the snippet; rendering runs it server-side in a sandbox.
abstract interface class PlaygroundBackend {
  /// Validates [code] and returns its diagnostics. Never executes the snippet.
  Future<ApiValidationResult> validate(String code);

  /// Renders [code] to a video, reporting capture [onProgress], and returns the
  /// outcome (a download URL on success, or a non-zero exit with the error).
  Future<RenderLaunchResult> render(String code, {void Function(RenderProgress)? onProgress});
}
