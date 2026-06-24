import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/real_network_http_overrides.dart';
import 'package:fluvie_example/render/spec_composition.dart';

/// Authors a [VideoSpec] from [prompt] using the environment-configured
/// provider (`FLUVIE_AI_PROVIDER` + API keys), optionally refining the spec at
/// [basePath]; writes the result to [specOut] and returns its [CompositionEntry].
///
/// [provider] overrides `FLUVIE_AI_PROVIDER` for this call (the CLI's
/// `--provider` flag); when null or empty the inherited environment selects the
/// backend. API keys always come from the environment.
///
/// This runs inside the capture harness (under `flutter test`), where the LLM
/// call happens in `tester.runAsync` before the deterministic frame loop. The
/// written spec is the reproducible artifact; rendering it never calls a model.
///
/// The whole body runs inside [HttpOverrides.runWithHttpOverrides] with a
/// [RealNetworkHttpOverrides] so the LLM request escapes `flutter_test`'s global
/// mock binding (which would otherwise answer every request with HTTP 400). The
/// `AiClient` is built inside that zone because `package:http` resolves the
/// active override when it constructs its `HttpClient`.
Future<CompositionEntry> authorComposition({
  required String prompt,
  required String specOut,
  String? basePath,
  String? provider,
  AiImage? lastFrame,
}) {
  return HttpOverrides.runWithHttpOverrides<Future<CompositionEntry>>(() async {
    final service = LlmVideoAuthorService(
      client: aiClientFromEnv(aiEnvForProvider(Platform.environment, provider)),
    );
    final base = basePath == null || basePath.isEmpty ? null : videoSpecFromFile(basePath);
    final spec = await service.author(prompt, base: base, lastFrame: lastFrame);
    writeSpecToFile(spec, specOut);
    return compositionFromSpec(spec);
  }, RealNetworkHttpOverrides());
}

/// Returns [base] with `FLUVIE_AI_PROVIDER` set to [provider] when it is
/// non-empty, otherwise [base] unchanged.
///
/// This bridges the capture harness's `FLUVIE_AI_PROVIDER` `--dart-define` (the
/// CLI's `--provider` flag) into the process-environment map [aiClientFromEnv]
/// reads, so the flag actually selects the backend. A given [provider] wins over
/// one already exported in [base].
Map<String, String> aiEnvForProvider(Map<String, String> base, String? provider) =>
    provider == null || provider.isEmpty ? base : {...base, 'FLUVIE_AI_PROVIDER': provider};
