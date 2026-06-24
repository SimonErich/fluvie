import 'package:fluvie_example/inspector/api_render_launcher.dart';
import 'package:fluvie_example/inspector/process_render_launcher.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';

/// The native default render backend: the `fluvie_server` server when
/// `FLUVIE_API_URL` is set (and `FLUVIE_RENDER_BACKEND` is not `local`),
/// otherwise the local desktop [ProcessRenderLauncher].
///
/// Configure with `--dart-define`s: `FLUVIE_API_URL`, `FLUVIE_API_TOKEN`,
/// and `FLUVIE_RENDER_BACKEND` (`local`|`api`).
RenderLauncher createRenderLauncher() {
  const apiUrl = String.fromEnvironment('FLUVIE_API_URL');
  const backend = String.fromEnvironment('FLUVIE_RENDER_BACKEND');
  if (backend != 'local' && apiUrl.isNotEmpty) {
    return ApiRenderLauncher(baseUrl: Uri.parse(apiUrl), token: _token());
  }
  return const ProcessRenderLauncher();
}

String? _token() {
  const token = String.fromEnvironment('FLUVIE_API_TOKEN');
  return token.isEmpty ? null : token;
}
