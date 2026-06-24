// Compiled, tested snippets for documentation/guides/authoring-with-specs.md.
// The `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker,
// so the page can never drift from the real authoring API.

import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

/// Authors a [Video] from a natural-language [prompt] using the provider and
/// key configured in the environment.
Future<Video> authorFromPrompt(String prompt) async {
  // #docregion author
  final client = aiClientFromEnv(Platform.environment);
  final service = LlmVideoAuthorService(client: client);
  final spec = await service.author(prompt);
  final video = buildVideo(spec);
  // #enddocregion author
  return video;
}
