# Authoring videos as data

A Fluvie video can be a JSON document. Save a video as a spec, load it back, and
render it. The same format is what an AI uses to write a video from a prompt.

A spec is one object: a size, an fps, and a list of scenes. Each scene has a
duration, an optional background, and a list of children. Each child has a type,
its content, and an `animate` list:

```json
{
  "fluvieSpec": 1,
  "size": "reels",
  "fps": 30,
  "scenes": [
    {
      "duration": "4s",
      "background": { "kind": "gradient", "colors": ["#1A2980", "#26D0CE"] },
      "children": [
        {
          "type": "Text",
          "text": "Hello, Fluvie",
          "style": { "color": "#FFFFFF", "fontSize": 72, "fontWeight": "w700" },
          "animate": [{ "preset": "fadeIn" }, { "preset": "pop" }]
        }
      ]
    }
  ]
}
```

## Load and build

Read a spec with `VideoSpec.fromJson`, then `buildVideo` turns it into a real
`Video` you can render:

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (load)" -->
```dart
final spec = VideoSpec.fromJson(jsonDecode(jsonText) as Map<String, Object?>);
final video = buildVideo(spec);
```

`buildVideo` is a pure function. The same spec always builds the same video. The
model that wrote the spec runs once, at authoring time, never inside the frame
loop.

## Save

Write a spec back to JSON with `toJson`:

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (save)" -->
```dart
final jsonText = jsonEncode(spec.toJson());
```

Re-reading the saved form is stable: the serialization is canonical, so a
load-then-save round trip settles after one pass.

## Anchors are names

In code an anchor is a token you pass around. In a spec it is a string id. Give
an element an `anchor`, then point a trigger at the same id:

```json
{
  "type": "Text",
  "text": "Title",
  "anchor": "intro",
  "animate": [{ "preset": "fadeIn", "duration": "30f" }]
}
```

```json
{
  "type": "Text",
  "text": "Subtitle",
  "animate": [{ "preset": "fadeIn", "at": { "kind": "after", "anchor": "intro" } }]
}
```

The loader mints one anchor per id for the whole document, so the trigger that
points at `"intro"` and the element that declares `"intro"` resolve to the same
anchor. The subtitle starts when the title finishes.

## Time is a string

Durations and delays are unit-tagged strings: `"2s"` seconds, `"30f"` frames,
`"500ms"` milliseconds, and `"0.3r"` a fraction of the window. A relative time
can carry a cap, as in `"0.2r@0.8s"`.

## A stable id

Every spec has a content digest. Identical specs share a digest, so an
AI-authored video keys the frame cache and names its output reproducibly:

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (digest)" -->
```dart
final id = spec.digest();
```

## What a spec can hold

- **Elements**: `Text`, `Box`, `Image`, `Counter`.
- **Backgrounds**: `color`, `gradient`, `radial`, `image`, `video`, `noise`,
  `vhs`.
- **Animations**: the named presets (`fadeIn`, `slideFade`, `pop`, `kenBurns`,
  and more) plus raw `from`/`to`/`fromTo` keyframes.
- **Transitions**: `cut`, `crossFade`, `wipe`, `zoom`, `slide`.

A node the format does not support fails loudly: `VideoSpec.fromJson` throws a
`FluvieSpecError` that names the document path of the problem, so a bad spec
never renders the wrong thing.

## Author with AI from Dart

The companion package `fluvie_ai` writes a spec from a prompt. Add it:

```sh
dart pub add fluvie_ai
```

Pick a provider, set its key in the environment, then author a spec and build it
like any other:

<!-- code-excerpt "examples/gallery/lib/snippets/ai_authoring_snippets.dart (author)" -->
```dart
final client = aiClientFromEnv(Platform.environment);
final service = LlmVideoAuthorService(client: client);
final spec = await service.author(prompt);
final video = buildVideo(spec);
```

`author` runs the model once and returns a validated `VideoSpec`. When the model
returns an invalid spec, the service feeds the validation error back for up to
three repair rounds before it gives up. Save the spec and you have a reproducible
artifact: rendering it never calls the model again.

### Providers

| Provider | `FLUVIE_AI_PROVIDER` | API key | Sees images |
| --- | --- | --- | --- |
| Claude (default) | `claude` | `ANTHROPIC_API_KEY` | yes |
| Gemini | `gemini` | `GEMINI_API_KEY` | yes |
| Mistral | `mistral` | `MISTRAL_API_KEY` | no |
| Ollama (local) | `ollama` | none | no |

`FLUVIE_AI_MODEL` overrides the model. `ollama` needs no key and runs against a
local server, the easiest way to try this offline.

## From the command line

Render an existing spec to a file:

```sh
fluvie render --spec promo.fluvie.json --out promo.mp4
```

Write a spec from a prompt with an LLM, save it, and render it in one step. The
provider and API keys come from the environment, so set them first:

```sh
export FLUVIE_AI_PROVIDER=claude   # or gemini, mistral, ollama
export ANTHROPIC_API_KEY=sk-...
fluvie generate "a 6s vertical title card, dark gradient, fade-in headline" \
  --out promo.mp4 --spec-out promo.fluvie.json
```

Refine the saved spec conversationally; re-rendering the same spec gives the same
video:

```sh
fluvie edit promo.fluvie.json "make the headline yellow and add a logo" \
  --out promo.mp4
```

On an `edit`, the harness renders a frame of the current video and sends it to
the model alongside the change, so a multimodal provider (Claude or Gemini) can
see what it is editing. The committed `.fluvie.json` stays the reproducible
artifact; the image only grounds the next edit.

`ollama` needs no key and runs against a local server, which makes it the
easiest way to try this offline.

## In the example app

The example inspector has a "Generate with AI" action in its app bar. It opens a
prompt panel that authors a spec with the same `VideoAuthorService`, then shows
a summary and the validated JSON. It reads the provider and key from the same
environment variables, so export them before launching the app.

## Where to next

- [Animating elements](animating-elements.md) for the full preset menu a spec
  can name.
- [Timing and triggers](timing-and-triggers.md) for how anchors and triggers
  resolve.
- [Exporting your video](exporting-your-video.md) to render a built spec to a
  file.
