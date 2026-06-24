import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_server/client.dart';

/// An [AiAuthorBackend] backed by a `fluvie_server` over HTTP.
///
/// Web-safe: it depends only on `package:fluvie_server/client.dart` (no
/// `dart:io`), so the browser demo can author through the server, which holds the
/// provider key and enforces the per-IP quota. The server authors a `VideoSpec`,
/// prints it to a Flutter-style `Video build()` snippet, and returns both; this
/// backend returns the snippet as soon as it appears (before the authoring render
/// finishes), so the editor fills fast.
///
/// Edits are surgical: the backend remembers the last authored spec and sends it
/// as the `base` of the server's spec-based edit, so a change touches only what
/// you ask. (A hand-edit to the code in the editor is not reflected back into the
/// spec, so a following AI edit builds on the last AI-authored version.)
final class ServerAiAuthorBackend implements AiAuthorBackend {
  /// Creates a backend against [baseUrl], authenticating with [token] when set.
  /// [client], [pollInterval], [timeout], and [wait] are injectable for tests.
  ServerAiAuthorBackend({
    required Uri baseUrl,
    String? token,
    ApiRenderClient? client,
    this.pollInterval = const Duration(seconds: 1),
    this.timeout = const Duration(minutes: 5),
    this.wait = _realWait,
  }) : _client = client ?? ApiRenderClient(baseUrl: baseUrl, apiToken: token);

  final ApiRenderClient _client;

  /// How often the render job is polled for the authored code.
  final Duration pollInterval;

  /// How long to wait for the server to author the code before giving up.
  final Duration timeout;

  /// The delay between polls; injectable so tests run without real waits.
  final Future<void> Function(Duration) wait;

  /// The spec that produced the current video, kept as the `base` for the next
  /// edit. A fresh generation replaces it; `null` (no prior generation) makes an
  /// edit fall back to a fresh prompt.
  Map<String, Object?>? _lastSpec;

  @override
  Future<AiAuthorResult> author(String prompt, {String? currentCode}) async {
    final base = _lastSpec;
    final request = (currentCode != null && base != null)
        ? ApiRenderRequest.edit(base: base, change: prompt.trim())
        : ApiRenderRequest.prompt(prompt.trim());
    try {
      final job = await _runRender(request);
      final code = job.code;
      if (code == null) {
        throw ApiClientException(job.error ?? 'The AI did not return any code');
      }
      _lastSpec = job.spec ?? _lastSpec;
      return AiAuthorResult(code: code);
    } on ApiClientException catch (error) {
      throw AiAuthorException(_friendlyMessage(error));
    }
  }

  Future<RenderJobView> _runRender(ApiRenderRequest request) async {
    final created = await _client.createRender(request);
    var latest = created;
    var waited = Duration.zero;
    // The authored code and spec land together, before the video finishes, so
    // stop as soon as the code is ready.
    while (latest.code == null && latest.isPending) {
      if (waited >= timeout) {
        throw const ApiClientException('Timed out waiting for the AI to author the video');
      }
      await wait(pollInterval);
      waited += pollInterval;
      latest = await _client.getJob(created.id);
    }
    return latest;
  }

  static String _friendlyMessage(ApiClientException error) => switch (error.statusCode) {
    429 => 'You have reached the free AI generation limit. Please wait a little and try again.',
    503 => 'AI generation is not available on this server.',
    _ => 'The video could not be generated. Try a different prompt.',
  };

  static Future<void> _realWait(Duration duration) => Future<void>.delayed(duration);
}
