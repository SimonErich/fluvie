import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';

/// The most pixels a posted spec's explicit `{width, height}` canvas may span
/// on either axis (8K). A spec is untrusted and the harness allocates a
/// `width * height * 4` frame buffer, so an unbounded size OOMs the worker.
/// The bound is PER AXIS, checked before any multiply, so a huge dimension
/// cannot overflow `width * height` to a small value and slip through. Named
/// presets (`reels`/`square`/`hd`/`fourK`) are always within this ceiling. The
/// authoritative bound is at the capture chokepoint (post-aspect); this is the
/// cheap early reject.
const int maxSpecDimension = 7680;

/// Rejects a posted spec (or an edit's base spec) whose explicit
/// `{width, height}` canvas is non-positive or whose width or height exceeds
/// [maxSpecDimension], before it can OOM a worker on the first frame. A named
/// preset or an aspect-derived size is left to the render. Throws
/// [ApiError.badRequest] (HTTP 400) on an out-of-bounds size.
void ensureSpecWithinBounds(RenderRequest request) {
  final spec = switch (request) {
    SpecRenderRequest(:final spec) => spec,
    EditRenderRequest(:final baseSpec) => baseSpec,
    _ => null,
  };
  final size = spec?['size'];
  if (size is! Map) return;
  final width = size['width'];
  final height = size['height'];
  if (width is! int || height is! int) return;
  // Per-axis, before any multiply: a huge width or height must not overflow
  // width*height to a small (or negative) value and pass.
  if (width <= 0 || height <= 0 || width > maxSpecDimension || height > maxSpecDimension) {
    throw ApiError.badRequest(
      'each of width and height must be positive and at most $maxSpecDimension (8K); '
      'got ${width}x$height',
    );
  }
}

/// Rejects an AI render (prompt/edit) whose selected provider has no configured
/// key, before the job is enqueued. Key/spec/code renders need no AI and pass.
/// Throws [ApiError.unavailable] (HTTP 503) when the provider is unconfigured.
void ensureAiConfigured(RenderRequest request, ServerConfig config) {
  final String? provider;
  if (request is PromptRenderRequest) {
    provider = request.provider;
  } else if (request is EditRenderRequest) {
    provider = request.provider;
  } else {
    return; // key/spec renders need no AI.
  }
  final selected = provider ?? config.aiEnv['FLUVIE_AI_PROVIDER'] ?? 'claude';
  if (selected == 'ollama') return; // local provider, no key needed.
  final keyVar = switch (selected) {
    'gemini' => 'GEMINI_API_KEY',
    'mistral' => 'MISTRAL_API_KEY',
    _ => 'ANTHROPIC_API_KEY',
  };
  if (!config.aiEnv.containsKey(keyVar)) {
    throw const ApiError.unavailable('AI rendering is not configured on this server');
  }
}
