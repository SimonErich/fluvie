import 'package:fluvie_example/inspector/api_render_launcher.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';

/// The web default render backend: always the `fluvie_api` server (the local
/// process launcher needs `dart:io`, unavailable on web).
///
/// When `FLUVIE_API_URL` is not configured the launcher reports a clear error at
/// render time rather than failing to compile.
RenderLauncher createRenderLauncher() {
  const apiUrl = String.fromEnvironment('FLUVIE_API_URL');
  if (apiUrl.isEmpty) return const _UnconfiguredLauncher();
  const token = String.fromEnvironment('FLUVIE_API_TOKEN');
  return ApiRenderLauncher(baseUrl: Uri.parse(apiUrl), token: token.isEmpty ? null : token);
}

/// Reports the missing configuration instead of rendering.
final class _UnconfiguredLauncher implements RenderLauncher {
  const _UnconfiguredLauncher();

  @override
  Future<RenderLaunchResult> render(
    String key, {
    void Function(RenderProgress)? onProgress,
  }) async => const RenderLaunchResult(
    exitCode: 1,
    stdout: '',
    stderr:
        'Rendering on web needs a fluvie_api server. '
        'Build with --dart-define=FLUVIE_API_URL=https://your-server',
  );
}
