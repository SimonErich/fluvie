import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_backend.dart';
import 'package:fluvie_server/client.dart';

/// Builds the Playground backend from the build-time `FLUVIE_API_URL`.
///
/// When it is not configured, an [_UnconfiguredPlaygroundBackend] reports a
/// clear error at use time rather than failing to compile (mirrors the render
/// launcher's web backend).
PlaygroundBackend createPlaygroundBackend() {
  const apiUrl = String.fromEnvironment('FLUVIE_API_URL');
  if (apiUrl.isEmpty) return const _UnconfiguredPlaygroundBackend();
  const token = String.fromEnvironment('FLUVIE_API_TOKEN');
  return ApiPlaygroundBackend(baseUrl: Uri.parse(apiUrl), token: token.isEmpty ? null : token);
}

/// A [PlaygroundBackend] backed by a `fluvie_server` over HTTP (web-safe: it
/// depends only on `package:fluvie_server/client.dart`).
final class ApiPlaygroundBackend implements PlaygroundBackend {
  /// Creates a backend against [baseUrl], authenticating with [token] when set.
  /// [client] and [pollInterval] are injectable for tests.
  ApiPlaygroundBackend({
    required Uri baseUrl,
    String? token,
    ApiRenderClient? client,
    this.pollInterval = const Duration(seconds: 1),
  }) : _client = client ?? ApiRenderClient(baseUrl: baseUrl, apiToken: token);

  final ApiRenderClient _client;

  /// How often a running render is polled.
  final Duration pollInterval;

  @override
  Future<ApiValidationResult> validate(String code) => _client.validate(code);

  @override
  Future<RenderLaunchResult> render(
    String code, {
    void Function(RenderProgress)? onProgress,
  }) async {
    try {
      final job = await _client.renderAndWait(
        ApiRenderRequest.code(code),
        pollInterval: pollInterval,
        onUpdate: (view) {
          final completed = view.completed;
          final total = view.total;
          if (completed != null && total != null) {
            onProgress?.call(RenderProgress(completed: completed, total: total));
          }
        },
      );
      return RenderLaunchResult(
        exitCode: 0,
        stdout: 'Rendered on the server',
        stderr: '',
        downloadUrl: job.video?.downloadUrl.toString(),
      );
    } on ApiClientException catch (error) {
      return RenderLaunchResult(exitCode: 1, stdout: '', stderr: error.message);
    }
  }
}

/// Reports the missing `FLUVIE_API_URL` instead of validating or rendering.
final class _UnconfiguredPlaygroundBackend implements PlaygroundBackend {
  const _UnconfiguredPlaygroundBackend();

  static const _message =
      'The Playground needs a fluvie_server. Build with '
      '--dart-define=FLUVIE_API_URL=https://your-server';

  @override
  Future<ApiValidationResult> validate(String code) async => const ApiValidationResult(
    ok: false,
    diagnostics: [
      ApiCodeDiagnostic(
        severity: ApiDiagnosticSeverity.error,
        message: _message,
        line: 1,
        column: 1,
      ),
    ],
  );

  @override
  Future<RenderLaunchResult> render(
    String code, {
    void Function(RenderProgress)? onProgress,
  }) async => const RenderLaunchResult(exitCode: 1, stdout: '', stderr: _message);
}
