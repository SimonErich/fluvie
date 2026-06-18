# fluvie_ai

Author [Fluvie](https://pub.dev/packages/fluvie) videos from natural language.
You write a prompt; a language model writes a `VideoSpec`; Fluvie renders it to a
real video file. The model runs once, at authoring time. Rendering the spec never
calls a model, so the output stays byte-for-byte deterministic.

[![pub package](https://img.shields.io/pub/v/fluvie_ai.svg)](https://pub.dev/packages/fluvie_ai)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## How it works

1. You give a prompt (and optionally an existing spec to refine).
2. `VideoAuthorService` sends it to an `AiClient` together with Fluvie's JSON
   Schema.
3. The reply is parsed into a `VideoSpec`. If it does not validate, the service
   sends the validation error back for up to three repair rounds.
4. `buildVideo(spec)` turns the spec into a `Video` you render like any other.

The spec is the artifact. Commit it, diff it, re-render it: the same spec always
produces the same frames.

## Install

```sh
dart pub add fluvie_ai
```

## Quick start

Pick a provider, set its key in the environment, then author a spec and build it:

```dart
import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

Future<Video> author(String prompt) async {
  final client = aiClientFromEnv(Platform.environment);
  final service = LlmVideoAuthorService(client: client);
  final spec = await service.author(prompt);
  return buildVideo(spec);
}
```

```sh
export FLUVIE_AI_PROVIDER=claude   # claude (default), gemini, mistral, ollama
export ANTHROPIC_API_KEY=sk-...
```

## Providers

| Provider | `FLUVIE_AI_PROVIDER` | API key env | Sees images |
| --- | --- | --- | --- |
| Claude (default) | `claude` | `ANTHROPIC_API_KEY` | yes |
| Gemini | `gemini` | `GEMINI_API_KEY` | yes |
| Mistral | `mistral` | `MISTRAL_API_KEY` | no |
| Ollama (local) | `ollama` | none | no |

`FLUVIE_AI_MODEL` overrides the model. Ollama needs no key and runs against a
local server, the easiest way to try this offline. Construct a client directly
when you do not want the environment:

```dart
final client = ClaudeAiClient(apiKey: myKey);
```

## Refine an existing spec

Pass the current spec as `base` to change it, and a rendered frame as `lastFrame`
so a multimodal provider (Claude or Gemini) can see what it is editing:

```dart
final next = await service.author(
  'make the headline yellow',
  base: current,      // the VideoSpec to change
  lastFrame: preview, // an AiImage of the current render
);
```

## Riverpod

`videoAuthorServiceProvider` builds the service from `aiClientProvider`. The
client has no default; override it once at the root:

```dart
ProviderScope(
  overrides: [
    aiClientProvider.overrideWith((ref) => aiClientFromEnv(Platform.environment)),
  ],
  child: const MyApp(),
);
```

In tests, override it with `FakeAiClient`, which replays canned replies with no
network.

## From the command line

The [`fluvie_cli`](https://pub.dev/packages/fluvie_cli) renderer wraps all of
this end to end:

```sh
fluvie generate "a 6s vertical title card, dark gradient, fade-in headline" \
  --out promo.mp4 --spec-out promo.fluvie.json
fluvie edit promo.fluvie.json "make the headline yellow" --out promo.mp4
```

## Documentation

See the Fluvie [AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

## License

MIT. See [LICENSE](https://opensource.org/licenses/MIT).
