# Generative media

Declare AI-generated video, images, music, speech, and sound effects right in
your `Video`. Fluvie generates each asset once, saves it in your project keyed by
a hash of the prompt, and then treats it like a local file on every later render.

You write what you want. Fluvie produces it before the frame loop, caches it, and
reuses it.

## What you get

The provider widgets live in `package:fluvie_ai/fluvie_ai.dart`:

- `GenerativeImage.flux(...)`, `GenerativeImage.gemini(...)`, `GenerativeImage.openai(...)`
- `GenerativeVideo.veo(...)` (Veo 3 returns video with an audio track)
- `GenerativeMusic.suno(...)`
- `GenerativeSpeech.eleven(...)`
- `GenerativeSoundFx.eleven(...)`

A visual widget (`GenerativeImage`, `GenerativeVideo`) goes in a scene's
`children` like any element. An audio widget (`GenerativeMusic`,
`GenerativeSpeech`, `GenerativeSoundFx`) also goes in a scene's `children`; it
paints nothing and contributes a track to the mix.

Import the AI widgets next to the usual pair:

<!-- code-excerpt "examples/gallery/lib/lessons/13_generative_content.dart (imports)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
```

Then declare a generated image inline and animate it like any element:

<!-- code-excerpt "examples/gallery/lib/lessons/13_generative_content.dart (image)" -->
```dart
Positioned.fill(
  child: GenerativeImage.flux(
    prompt: 'a neon skyline at dusk, wide angle',
    fit: BoxFit.cover,
  ).animate([Animation.kenBurns(zoom: 1.2)]),
),
```

Lesson 13 renders exactly this. See the [API spec](https://github.com/SimonErich/fluvie/blob/main/concept/API_SPEC.md)
for the full type reference.

## Set up your keys

Pass provider API keys through the environment (or an explicit `GenerativeConfig`
from `package:fluvie_ai/generative.dart`). Nothing secret is committed.

```sh
export GEMINI_API_KEY=...        # Gemini images and Veo video
export OPENAI_API_KEY=...        # OpenAI images
export BFL_API_KEY=...           # Flux images
export ELEVENLABS_API_KEY=...    # speech and sound effects
export SUNO_API_KEY=...          # music (via sunoapi.org)
```

Then install the resolver once where you start your render. Build it with
`fluvieGenerativeResolverFor()` (it reads the keys above) and pass it to a render
as the `generative:` argument, or install it as the `generativeResolverProvider`
override. Without a resolver, a generative widget renders a placeholder in a live
preview and a clear error in a capture.

## How it works

Fluvie already resolves every `Image`, `Clip`, and snapshot before the frame loop
so capture stays synchronous. Generative media adds one step in front of that
pass:

1. Fluvie walks your tree and collects every generative source.
2. It generates each one (or reads it from the cache) and writes the bytes to
   `.fluvie/generative/<provider>/<hash>.<ext>` with a `.json` sidecar.
3. The produced file folds back in as a normal local source. From here a
   generated image paints like `Image.file`, a generated video plays like a
   `Clip`, and generated audio mixes like any track.

The detection is automatic. You do not flag anything. If your tree holds no
generative widget, the step is skipped and costs nothing.

## Caching and seeds

The cache key is a hash of the provider, model, prompt, sorted options, and the
optional seed.

- No `seed`: one prompt yields one stable result, reused forever.
- A `seed`: each distinct seed yields a different result, still deterministic for
  the same `(prompt, seed)`.

The cache directory lives in your project so it is safe to commit. Commit it and
your teammates and CI reuse the exact assets and never call a paid API again.
Override the location with `FLUVIE_GENERATIVE_CACHE_DIR`.

## Audio and video together

A generated video that carries its own audio (Veo 3) keeps that track. The track
plays where the clip plays, delayed to its scene window, so picture and sound stay
in sync because they are the same file. Set `withAudio: false` to drop it.

<!-- code-excerpt "examples/gallery/lib/lessons/13_generative_content.dart (video)" -->
```dart
Widget generatedClip() => GenerativeVideo.veo(prompt: 'a man walking down the street', seconds: 6);
```

Generated music feeds beat detection, so `Trigger.beat` works against a Suno bed.
A generated narration or sound effect mixes like a hand-written `Audio` track.

<!-- code-excerpt "examples/gallery/lib/lessons/13_generative_content.dart (audio)" -->
```dart
Widget generatedMusic() => GenerativeMusic.suno(prompt: 'lofi hip hop, 90bpm', seconds: 10);

Widget generatedNarration() => GenerativeSpeech.eleven(text: 'Welcome to Fluvie.', voice: 'rachel');
```

## Offline and CI

For a build server that must never call a paid API, set
`FLUVIE_GENERATIVE_OFFLINE=1`. Fluvie then serves only cached assets and fails
loudly on a miss, so a render is reproducible from the committed cache. Cap a
single render with the `maxGenerations` budget on `GenerativeConfig`.

## Security

Keys come from the environment or an injected config, never from the tree, and
are never logged. Generated downloads pass the same network allowlist and
validation as any remote media. The cache writes are atomic, so a crashed render
never leaves a half-written asset behind.

## Where to next

- [AI and MCP](ai-and-mcp.md) to author whole videos from a prompt.
- [Audio and captions](audio-and-captions.md) for the mix your generated tracks join.
- [Exporting your video](exporting-your-video.md) to render the result to a file.
