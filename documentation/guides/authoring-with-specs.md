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

- **Elements**: `Text` (with `style`, `textAlign`, `maxLines`, or styled
  `spans` instead of `text` — each span an optional `style` and a `link`
  that underlines and lands on the span's semantics, never a tap
  target), `Box`,
  `Image` (with `fit`, `cornerRadius`, `crop`, and a `frame` style),
  `Counter` (with `ease` and `currency`/`percent` variants), `Shape`
  (`line`, `rect`, `circle`, and SVG-subset `path` kinds), `Arrow`,
  `Connector`, `Clip` (source, `trim`, `fit`, `volume`, audio
  `fadeIn`/`fadeOut`, a playback `speed`, and a preview `poster`), `Typewriter`
  (`speed`, `caret`,
  `style`), `Markdown` (`source`, `reveal`), `Terminal` (`lines` of
  `cmd`/`out`, `prompt`, `chrome`, `typingSpeed`, `lineGap`), and `Code`
  (`language`, a `dark`/`light` `theme`, a typed or line-by-line `reveal`,
  `focusLines`, `highlightLines`, and a diff form via `after`), and
  `Chart` (every `variant`: `bar`, `pie`, `donut`, `line`, `area`,
  `scatter`, with `data`, multi-`series`, scatter `points`, `reveal`,
  `stagger`, and a donut `innerRadius`). The experimental snapshot
  surfaces serialize too: `Mermaid` (`theme`, a node/edge `reveal`,
  `fit`) and `WebView`/`Html` (an absolute `uri` or inline `source`, a
  required `viewport`, plus `scroll`, `clip`, `fit`). So do the audio
  `Bars` (`count`, `band`, `gain`, and an `Audio.track` anchor id in
  `track`) and the title annotations `LowerThird` (`name`, `title`,
  `reveal`, `color`) and `TitleCard` (`title`, `subtitle`, `reveal`,
  `color`). The wrapper elements nest one full element in a `child`
  (itself animatable and placeable, to any depth): `Snapshot` (`fit`),
  `DeviceFrame` (a `phone`/`browser`/`tablet` `variant`, a phone
  `notch`, a browser `url`), `Callout` (`label`, `target`, `labelAt`,
  `color`), and `Spotlight` (`region`, `reveal`, `color`); `LowerThird`
  and `TitleCard` take the same optional `child`. A `Box` also takes
  a `decoration` (color, corner radius, border, gradient, shadow).
  Every element additionally takes a `shared` string id, a sibling of
  `anchor`: two elements naming the same id in adjacent scenes pair into
  one hero morph across the transition between them. A `Group` nests a
  whole `children` list inside one box: the group's `transform` places
  the box, each child's `transform` is a fraction of it, and `animate`
  on the group moves everything inside as one unit. Groups nest to any
  depth; an empty group renders nothing. Every element also takes
  `visible`: set it to `false` and the element renders nothing while
  keeping its place in the document, and the flag counts into the
  digest because hiding changes the render.
- **Placement**: a fractional `transform` per element (`x`, `y`, `w`, `h`,
  `rotation`, `opacity`, `anchor`) on a `layout: canvas` scene; without one,
  elements center-stack.
- **Time windows**: every element takes `show`, the serialized form of the
  runtime's `show({from, to})` — the element appears at `from` and
  disappears at `to`, both inside its scene:

  ```json
  {
    "type": "Clip",
    "source": { "kind": "asset", "value": "media/b-roll.mp4" },
    "show": { "from": "2s", "to": "6.5s" }
  }
  ```

  A missing `from` means the scene start and a missing `to` the scene end;
  an empty `show` is invalid (drop the key instead). The window rides the
  element's one `.animate(...)` call as its `window:` argument, so the
  element's animations resolve inside it: a clip that enters at `2s` plays
  its `fadeIn` at `2s`. On a `Group` the whole group windows as one unit,
  and `visible: false` still wins — a hidden element never mounts, window
  or not.
- **Backgrounds**: `color`, `gradient`, `radial`, `image`, `video`, `noise`,
  `vhs`. The gradient kinds (and a decoration's `gradient`) take an optional
  `stops` list: one 0..1 offset per color, non-decreasing; leave it out and
  the colors space evenly.
- **Animations**: the named presets (`fadeIn`, `slideFadeIn`, `pop`,
  `kenBurns`, `maskWipeIn`, `glitchIn`, `float`, `pulse`, and more), the
  color and pixel effects (`color`, `gradientShift`, `scanlines`,
  `chromatic`, `bloom`, `parallax`, `particles`, the experimental
  `shader`), the audio-reactive `scaleY` and `pulse` (an `on` band, a
  `gain`, an `Audio.track` anchor id in `track`), the path-following
  `along` (an SVG `path` string, `orient`, `phase`), raw
  `from`/`to`/`fromTo` keyframes, and multi-stop `keyframes`: a list of
  at least two stops, optional per-segment `easings` (one per segment),
  optional `positions` (one time per stop, strictly increasing), and a
  `phase`. Offsets in a stop are element-relative (`y: 0.6` is 0.6
  element heights down). The stop positions are `positions`, so `at`
  keeps meaning the start trigger:

  ```json
  {
    "keyframes": [
      { "opacity": 0, "y": 0.6 },
      { "opacity": 1, "y": -0.15 },
      { "y": 0 }
    ],
    "easings": ["out", "smooth"],
    "positions": ["0f", "10f", "24f"],
    "duration": "24f",
    "at": "sceneStart"
  }
  ```

  A `shader` asset must be a plain relative asset path. `Animation.custom`
  stays code-only: an arbitrary Dart effect has no data form.
- **Transitions**: `cut`, `crossFade`, `wipe`, `zoom`, `slide`.
- **Theme tokens**: a top-level `theme` block holds named design tokens: a
  `palette` of colors, a `typeScale` of text styles, `spacing` sizes, and
  `motion` defaults. Any color field may then reference the palette as
  `{"token": "accent"}` instead of a literal, and a style object may adopt a
  type-scale entry whole through its own `"token"`, with sibling literal
  fields winning per field:

  ```json
  {
    "theme": {
      "palette": { "accent": "#FF6C5CE7" },
      "typeScale": { "heading": { "fontSize": 42, "fontWeight": "w700" } }
    }
  }
  ```

  Then `"color": {"token": "accent"}` colors an element and
  `"style": {"token": "heading", "fontSize": 90}` styles one with the
  heading scale at size 90. Literals keep working everywhere. Tokens resolve
  while the document builds; an unknown name (or a token without a theme)
  fails loudly with the known names and the document path. The theme counts
  into the render digest, so retinting one token re-renders everything bound
  to it. Theme values themselves stay literal (a token cannot reference a
  token), `spacing` is stored, validated, and digested for editing tools but
  resolved by nothing in the engine yet, and `motion` composes *under* an
  explicit `motionDefaults` per field (the explicit value wins). Printed
  Dart resolves every token to its literal and leads with a comment saying
  so, because plain fluvie code has no theme object.
- **Masters**: a top-level `masters` block holds named slide layouts. A
  master is an optional `background`, a `layout` intent, and `children` that
  mix fixed chrome (full elements: logos, footers) with named
  `Placeholder` slots:

  ```json
  {
    "masters": {
      "content": {
        "background": { "kind": "color", "color": "#FF101018" },
        "children": [
          { "type": "Box", "color": "#FF6C5CE7",
            "transform": { "x": 0.5, "y": 0.94, "w": 1.0, "h": 0.06 } },
          { "type": "Placeholder", "slot": "title",
            "transform": { "x": 0.5, "y": 0.3, "w": 0.9, "h": 0.3 },
            "style": { "fontSize": 34, "fontWeight": "w700" } }
        ]
      }
    }
  }
  ```

  A scene adopts one by name and fills its slots:
  `"master": "content", "fills": { "title": { "type": "Text", "id": "s1-title",
  "text": "Hello" } }`. The master applies at build time with no copies, so
  editing a master changes every adopting scene. The layering is: master
  background (unless the scene declares its own; the scene wins), master
  children in order (each placeholder replaced by its fill, unfilled slots
  rendering nothing), then the scene's own children on top. A fill is a
  scene-owned element: it carries its own `id` (a step may reveal it), and
  its own `transform` overrides the placeholder's; a placeholder's `style`
  defaults merge *under* the fill's style per field. Master children carry
  no `id`, `anchor`, or `shared` (they are chrome, not per-scene elements),
  a `Placeholder` is legal only inside a master, and an unknown master name
  or slot fails loudly at parse. A scene without a master is fully freeform.
  Masters count into the render digest; printed Dart prints adopting scenes
  resolved, behind a `// master "..." applied for the printed build` comment.
- **Audio**: a top-level `audio` list of tracks spanning the video, and an
  optional `audio` list per scene starting with it. Each track mirrors
  `Audio.music` or `Audio.sfx` field for field:

  ```json
  {
    "audio": [
      { "kind": "music",
        "source": { "kind": "file", "value": "/home/ada/music/bed.mp3" },
        "volume": 0.8, "fadeIn": "30f", "fadeOut": "60f", "loop": true,
        "trim": { "from": "0f", "to": "900f" }, "track": "bed" }
    ],
    "scenes": [
      { "duration": "150f",
        "audio": [
          { "kind": "sfx",
            "source": { "kind": "asset", "value": "audio/whoosh.mp3" },
            "at": { "kind": "at", "time": "500ms" } }
        ] }
    ]
  }
  ```

  The `source` is the same `{kind, value}` object images and clips use. A
  music track carries `volume`, `fadeIn`/`fadeOut`, `loop`, `trim`, and
  `track` — an anchor id naming its analysed beat grid, so
  `{"kind": "beat", "track": "bed"}` triggers resolve against it. An sfx
  track carries `at` (any trigger; missing means the owner's start) and
  `volume`. `at` on a music track and a music-only key on an sfx track fail
  loudly, because the constructors force exactly those fields. The engine
  consumes audio: the build hands the lists to `Video.audio` and
  `Scene.audio`, the mix collects them video-first in declaration order, and
  they count into the digest. The shape is fixed in the
  [video-mode ADR](../contributing/video-mode-document.md).
- **Lanes**: a top-level `lanes` list declaring the rows an editing timeline
  draws material on, and an optional `lane` on any element or audio track
  naming one of them:

  ```json
  {
    "lanes": [
      { "id": "v1", "name": "Video 1" },
      { "id": "a1", "name": "Music", "kind": "audio", "height": 56, "muted": true }
    ]
  }
  ```

  A lane says **where material is shown, never what order it paints in**:
  paint order stays the `children` list. A lane takes an `id` (required, and
  unique — a reference has to name exactly one row), an optional `name`, a
  `kind` of `video` or `audio`, `locked`, `muted`, and a `height`. A `lane`
  that names no declared lane fails loudly rather than being dropped.

  Only `muted` reaches the render: a muted lane's audio tracks are left out
  of the build, and out of the Dart `fluvie print` writes, because a mute the
  export ignored would be a lie you only find in the file. `locked`, `height`
  and `name` are for the tool drawing the timeline.

  The key is `lane` and never `track`. `track` is already a content property
  in three places — the `Bars` beat grid, a music track's beat anchor, and the
  reactive `pulse` and `scaleY` arguments — and reserving that name would pull
  it out of an element's properties and silently kill every beat grid.
- **Effects**: an ordered `effects` list on any element — thirteen surfaces
  that wrap it:

  ```json
  {
    "type": "Clip",
    "source": { "kind": "asset", "value": "media/b-roll.mp4" },
    "effects": [
      { "kind": "grain", "amount": 0.35 },
      { "kind": "vignette", "amount": 0.55 },
      { "kind": "bloom", "amount": 0.2, "enabled": false }
    ]
  }
  ```

  The thirteen: `grain` (amount), `vignette` (amount), `scanlines` (spacing,
  opacity), `chromatic` (px), `grade` (exposure, contrast, saturation,
  temperature, tint), `curves` (a `curves` object, intensity), `lut` (asset,
  intensity), `blur` (sigma), `bloom` (amount), `glitch` (intensity, from,
  reverse), `particles` (a
  `particles` object), `shader` (asset, uniforms), and `parallax` (depth).
  Every default is the effect's own current value, so a stack that names
  nothing renders what it always rendered. A bare grade composes to the
  identity matrix and is a pixel-for-pixel no-op.

  `curves` holds channel point lists under `master`, `red`, `green` and
  `blue`, each a list of `[x, y]` pairs on the unit square, evaluated as a
  monotone cubic through the points. `lut` names a `.cube` file: at most
  4 MB, `LUT_3D_SIZE` 2 to 64, unit domain only, validated before anything
  reads it, because a LUT file is external input. Both apply through a warm
  fragment shader over the rendered element, and both carry an `intensity`
  that mixes toward the untouched frame. The colour-space contract is
  simple on purpose: non-linear sRGB in, non-linear sRGB out, no transfer
  function on either side. At intensity zero, and for all-identity curves,
  the element mounts unwrapped: an exact no-op, not a near one.

  The stack composes by **class, then list order**: transform-class effects
  (`parallax`) innermost and pixel-class outermost, each keeping the order it
  was written in. That is the same transform-then-pixel discipline `animate`
  already applies, so a stack reads the same however it was typed.

  Every numeric parameter has an honest range, and a value outside it is
  refused rather than silently clamped into something you did not write.
  `enabled: false` mounts nothing and stays in the document, exactly as
  `visible: false` does for an element — you turned it off, you did not delete
  it.

  In Dart the same stack is `.effects([Effect.grain(amount: 0.35), ...])`, in
  the same slot: inside the element's `animate` wrapper and outside the element
  itself.

  **Keyframed parameters.** Any numeric parameter takes either a literal or a
  keyframed value: ordered stops, one position per stop, one easing per
  segment. The vocabulary is the `keyframes` animation form's on purpose, so
  you learn it once:

  ```json
  {
    "kind": "vignette",
    "amount": {
      "values": [0, 0.9],
      "positions": ["0f", "90f"],
      "easings": ["smooth"]
    }
  }
  ```

  The ramp runs over the element's own life: `0f` is the frame the element
  comes alive, and outside its stops the value holds rather than
  extrapolates. Two stops minimum, because one stop is a plain number wearing
  a list. Every stop faces the same range a literal would, because a ramp to 5
  is as wrong as a 5. `positions` is required, one per stop, strictly
  increasing; `easings` is optional and defaults to linear segments.

  In Dart a keyframed effect speaks the spec spelling, because the named
  factories take plain numbers and a parameter that changes says so through
  its own declaration:

  <!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (effect-stack)" -->
  ```dart
  return child.effects([
    Effect.grain(amount: 0.35),
    Effect.spec(
      EffectSpec(
        EffectSpecKind.vignette,
        params: {
          'amount': KeyframedNumber.linear(
            values: const [0, 0.9],
            positions: const [Time.zero, Time.frames(90)],
          ),
        },
      ),
    ),
  ]);
  ```
- **Overlays**: a top-level `overlays` list of elements that live outside
  every scene, on the whole video's clock:

  ```json
  {
    "overlays": [
      { "id": "ov-logo", "type": "Image",
        "source": { "kind": "asset", "value": "media/logo.png" },
        "transform": { "x": 0.9, "y": 0.12, "w": 0.12, "h": 0.12 },
        "show": { "from": "0f", "to": "180f" } }
    ]
  }
  ```

  An overlay is **one element for the whole video**. It is mounted once, never
  re-parented across a boundary, and its `show` window resolves against the
  video's own length rather than a scene's — so it holds through every cut and
  every blend without blinking. That is the one thing a `shared` hero morph can
  never be: a morph is two elements made to look like one across a cut, and an
  overlay *is* one.

  Overlays take no part in the offset math. Adding one never lengthens the
  video and never moves a boundary. They paint above every scene, in
  declaration order, and below the captions.

  An overlay may not declare `shared` — it already runs the whole video, so
  there is no boundary for it to morph across, and a document that tries is
  refused rather than quietly ignored. Which slide an editor draws an overlay
  on is editorial, so it lives in the `editor` block (`overlayHomes`) and never
  moves the content digest.
- **Steps and notes**: a scene-level `steps` list (each entry a group of
  child ids to reveal together, the list order being the step order;
  children in no step show on entry) and `notes` objects (`text`,
  `highlights`) on the scene and on any step. Fluvie stores, validates, and
  round-trips both, and they count into the digest, but rendering ignores
  them: a rendered video plays straight through. Only `fluvie_presenter`
  interprets them, through `deckFromSpec`; the shapes are fixed in the
  [steps-and-notes ADR](../contributing/steps-notes-digest.md).

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

## Keep generated Dart readable

`fluvie generate "a short cat story" --dart-out lib/my_video.dart --no-render` writes native Flutter
composition code for review before capture. Element IDs and clip transitions
print as `ElementId`, `ClipTransition`, and `ClipTransitionGroup`; clip-lane gain
prints through `ClipAudio.scaledBy`, preserving authored fades and automation.
The runtime algorithms are shared with the spec adapter. You can edit the Dart
without routing ordinary authoring through `VideoSpec.fromJson`.
