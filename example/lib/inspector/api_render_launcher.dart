import 'package:fluvie_api/client.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';

/// A [RenderLauncher] that renders through a `fluvie_api` server over HTTP.
///
/// Web-safe (it depends only on `package:fluvie_api/client.dart`), so the hosted
/// web example uses it where the local `ProcessRenderLauncher` cannot run. It
/// submits the composition key, polls until the render finishes, and returns the
/// download URL.
final class ApiRenderLauncher implements RenderLauncher {
  /// Creates a launcher against [baseUrl], authenticating with [token] when set.
  /// [client] is injectable for tests.
  ApiRenderLauncher({required this.baseUrl, this.token, ApiRenderClient? client})
    : _client = client ?? ApiRenderClient(baseUrl: baseUrl, apiToken: token);

  /// The render API base URL.
  final Uri baseUrl;

  /// The bearer token, or `null` for an open server.
  final String? token;

  final ApiRenderClient _client;

  @override
  Future<RenderLaunchResult> render(String key, {void Function(RenderProgress)? onProgress}) async {
    try {
      final job = await _client.renderAndWait(
        ApiRenderRequest.key(key),
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
        stdout: 'Rendered $key on the server',
        stderr: '',
        downloadUrl: job.video?.downloadUrl.toString(),
      );
    } on ApiClientException catch (error) {
      return RenderLaunchResult(exitCode: 1, stdout: '', stderr: error.message);
    }
  }
}
