import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_backend.dart';
import 'package:fluvie_server/client.dart';

/// A scriptable [PlaygroundBackend] for view-model and widget tests.
///
/// Set [validateResult] and [renderResult] (or their error variants) to drive a
/// single call; [progressTicks] are replayed to `onProgress` before [render]
/// completes. Records the last code each method saw for assertions.
final class FakePlaygroundBackend implements PlaygroundBackend {
  /// Creates a fake; every field defaults to a clean success.
  FakePlaygroundBackend({
    this.validateResult = const ApiValidationResult(ok: true, diagnostics: []),
    this.renderResult = const RenderLaunchResult(
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
      downloadUrl: 'https://api.test/v1/files/rnd_1/video.mp4',
    ),
    this.progressTicks = const [],
    this.validateError,
    this.renderError,
  });

  /// The result [validate] returns (unless [validateError] is set).
  ApiValidationResult validateResult;

  /// The result [render] returns (unless [renderError] is set).
  RenderLaunchResult renderResult;

  /// Progress snapshots replayed to `onProgress` during [render].
  List<RenderProgress> progressTicks;

  /// When set, [validate] throws this instead of returning.
  Object? validateError;

  /// When set, [render] throws this instead of returning.
  Object? renderError;

  /// The code passed to the most recent [validate], or null.
  String? lastValidatedCode;

  /// The code passed to the most recent [render], or null.
  String? lastRenderedCode;

  /// How many times [validate] was called.
  int validateCalls = 0;

  @override
  Future<ApiValidationResult> validate(String code) async {
    validateCalls++;
    lastValidatedCode = code;
    final error = validateError;
    // A test seam: simulate any failure the real transport might raise.
    if (error != null) throw error; // ignore: only_throw_errors
    return validateResult;
  }

  @override
  Future<RenderLaunchResult> render(
    String code, {
    void Function(RenderProgress)? onProgress,
  }) async {
    lastRenderedCode = code;
    if (onProgress != null) progressTicks.forEach(onProgress);
    final error = renderError;
    // A test seam: simulate any failure the real transport might raise.
    if (error != null) throw error; // ignore: only_throw_errors
    return renderResult;
  }
}
