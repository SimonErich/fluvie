/// Generates a text completion through the provider-agnostic contracts.
///
/// The [FakeTextGenerator] used here needs no API key, so the example runs
/// offline: `dart run example/main.dart`. Swapping in a real provider is one
/// constructor call; see the comment at the end of `main`.
library;

import 'dart:io';

import 'package:ai_abstracted/ai_abstracted.dart';

Future<void> main() async {
  // Every medium has the same shape: a typed request in, a GenerationResult
  // out. Text, image, video, speech, sound effects, and music all follow it.
  final generator = FakeTextGenerator(
    text: 'A tiny film studio that already speaks Flutter.',
  );

  final result = await generator.generateText(
    const TextRequest(
      prompt: 'Describe Fluvie in one sentence.',
      system: 'Answer in a single short sentence.',
      seed: '42',
    ),
    onProgress: (progress) => stdout.writeln('stage: ${progress.stage.name}'),
  );

  stdout
    ..writeln('model: ${result.metadata.model}')
    ..writeln('completion: ${result.text}');

  // The real providers implement the same contract, so moving off the fake is
  // one constructor swap (the key comes from ANTHROPIC_API_KEY):
  //
  //   final credentials = credentialsFromEnv(ProviderId.claude, Platform.environment);
  //   final generator = ClaudeTextClient(credentials: credentials!);
}
