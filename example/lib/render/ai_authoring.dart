import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/spec_composition.dart';

/// Authors a [VideoSpec] from [prompt] using the environment-configured
/// provider (`FLUVIE_AI_PROVIDER` + API keys), optionally refining the spec at
/// [basePath]; writes the result to [specOut] and returns its [CompositionEntry].
///
/// This runs inside the capture harness (under `flutter test`), where the LLM
/// call happens in `tester.runAsync` before the deterministic frame loop. The
/// written spec is the reproducible artifact; rendering it never calls a model.
Future<CompositionEntry> authorComposition({
  required String prompt,
  required String specOut,
  String? basePath,
  AiImage? lastFrame,
}) async {
  final service = LlmVideoAuthorService(client: aiClientFromEnv(Platform.environment));
  final base = basePath == null || basePath.isEmpty ? null : videoSpecFromFile(basePath);
  final spec = await service.author(prompt, base: base, lastFrame: lastFrame);
  writeSpecToFile(spec, specOut);
  return compositionFromSpec(spec);
}
