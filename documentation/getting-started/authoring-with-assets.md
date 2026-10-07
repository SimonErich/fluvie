# Create a video from local assets

Start with an ordinary Flutter project. Keep your composition in Dart, drop
your photos, clips, soundtrack, and story notes into `assets/`, then preview and
render the same `Video`.

```sh
flutter create cat_story
cd cat_story
flutter pub add fluvie
dart pub global activate fluvie_cli
```

For an unpublished checkout, [activate its CLI directly](installation.md#use-an-unpublished-checkout)
with `dart tool/activate_cli.dart` from that repository, then use
`fluvie init` instead of `flutter pub add fluvie`. The source-installed CLI
discovers its checkout automatically; `--fluvie-path` selects another one.
Run `flutter pub get` in your project after initialization.

An existing Flutter project works too. `fluvie init` adds a starter composition
and merges its dependency and asset setup into the existing project.

## Give the assistant a clear starting point

Keep related files together. Nested asset directories are supported:

```text
assets/
  cat/playing.mp4
  cat/sleeping.jpg
  music/song.mp3
  story.txt
lib/
  my_video.dart
```

Ask your coding assistant:

> Create a video about the life of my cat using the files under assets/. Use
> Fluvie and write readable Flutter code in lib/my_video.dart with a top-level
> Video build(). Read story.txt for the narrative, inspect the real media before
> choosing timing, preview the result, and render the MP4.

Use `fluvie docs --context` to give an assistant the installed version's offline
authoring guide. The [AI and MCP guide](../guides/ai-and-mcp.md) explains the
documentation tools and built-in generation workflow. An assistant should use
actual asset filenames and supported APIs rather than inventing either.

## Read text files and inspect media

Story text files are authoring input. Read the notes before choosing captions or
scene order; they do not become a soundtrack automatically. Inspect clip duration,
dimensions, and embedded audio before choosing a trim. Keep original filenames
in the code so an error identifies the asset that needs attention.

```sh
fluvie doctor --json
fluvie assets ./assets --json
fluvie validate ./lib/my_video.dart --json
```

The inventory is read-only by default. Add `--download-tools` to install missing
native tools explicitly; render and preview provision them automatically. It
recurses through nested folders and reports original paths,
media facts, bounded text previews, and declared font families. It does not
invent a story or infer the content of a clip. Validation reads the original
Dart file, so its relative imports keep working; it never executes the code.

Validation warns about obvious wall-clock and unseeded random reads in video
construction with `nondeterministic_video`. Derive animation from the authored
frame and use stable seeds or fixed input dates. The [frame-builder guide](../advanced/frame-builder.md)
explains the rule and its limits.

For a built-in model, select reusable visual and story evidence:

```sh
fluvie assets ./assets --contact-sheets \
  --catalog-out build/fluvie/assets.catalog.json
fluvie generate "the life of my cat" --catalog build/fluvie/assets.catalog.json \
  --context-file assets/story.txt --dart-out lib/my_video.dart --no-render
```

The catalog binds observations and pictures to source hashes; local sheet creation
does not upload them. Add `--image-evidence` only when you want your selected
vision provider to inspect the sheets. See [asset evidence](../guides/asset-evidence.md)
for timestamped observations and transcripts.

## The composition is ordinary Flutter code

This example expects the filenames shown above; change them to your own files.
The music and clip can be edited independently, and Flutter's `Align`, `Text`,
`Padding`, and layout widgets work inside the scene.

<!-- code-excerpt "examples/gallery/lib/snippets/authoring_snippets.dart (asset-story)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// A small story using files in the project's assets folder.
Video build() => Video(
  size: VideoSize.hd,
  poster: 1.seconds,
  audio: const [Audio.music('assets/music/song.mp3', volume: 0.3)],
  scenes: [
    Scene(
      duration: 4.seconds,
      children: [
        Clip.asset('assets/cat/playing.mp4', fit: BoxFit.cover, audio: const ClipAudio.muted()),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Text('A day in the life of my cat', style: TextStyle(fontSize: 64)),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);
```

The scene defines its own duration. `Video` calculates the total, and timing
uses seconds or frames without a second animation clock. Explicitly mute a
clip when its original audio should not compete with your soundtrack.

## Preview and render

```sh
fluvie preview ./lib/my_video.dart
fluvie render ./lib/my_video.dart
```

The default output is `build/fluvie/my_video.mp4`. The authored `Video` supplies
its size, FPS, duration, export mode, and poster. With no export mode, Fluvie
uses high-quality MP4. Override a choice when needed:

```sh
fluvie render ./lib/my_video.dart --out cat_story.mp4
fluvie render ./lib/my_video.dart --frames 30 --quality low
fluvie render ./lib/my_video.dart --machine
```

Fluvie prepares its capture harness and tooling in a user cache outside your
project. You maintain the composition and assets; you do not add a capture
test, registry, or rendering-only dependencies. Flutter may create its normal
ignored build output. The CLI provisions its native encoding tools when needed. `--machine` emits
JSON-line progress and a final artifact event with the output and receipt paths.
The receipt compares actual encoded facts with the requested output. A failed
verification exits unsuccessfully and keeps a diagnostic receipt for inspection.
For subsequent renders, local inputs invalidate cached frames automatically.
Use `--cache-key <version-or-hash>` for reliably identified external inputs, or
`--no-cache` when their identity can change without being tracked.
The retained `my_video.render.json` records source/input fingerprints, tools,
settings, actual encoded media metadata, output SHA-256, and any authored poster
identity for review.

Preview prints a local browser URL. Pass `-d chrome` to open Chrome, or use a
Flutter desktop device when you need one. The CLI supplies its local native media
bridge automatically, so browser preview can use formats beyond the browser's
own codec support. Click the sound control to enable audio. Independently hosted
browser rendering has different codec limits; see the
[web rendering guide](../guides/on-device-web-rendering.md).

To embed the player in your own Flutter app:

<!-- code-excerpt "examples/gallery/lib/snippets/authoring_snippets.dart (video-preview)" -->
```dart
/// Embeds the authored composition in your own Flutter app.
Widget preview() => const VideoPreview.builder(builder: build);
```

## Make changes easy to review

```sh
fluvie review ./lib/my_video.dart --determinism --json
fluvie review ./lib/my_video.dart --render --strict-decode --json
fluvie edit ./lib/my_video.dart "make the closing title warmer" --no-render
```

Review combines diagnostics, mounted facts and representative captures.
`--determinism` compares reverse seeks and a fresh mount, invoking the entry
function again to check factory and widget initialization. Inspect its sampled
pictures as well as the diagnostics; a passing check does not judge the story or
prove every frame or platform identical. A strict
render review also decodes the complete encoded result. A Dart edit preserves
unchanged code and keeps the original in a `.fluvie.bak` file after validation.
See [reviewing a video](../guides/reviewing-a-video.md) for the report and its limits.

Build one function per scene when the story grows. Use meaningful names,
explicit trims, and comments explaining editorial choices. Keep generated
output in `build/` and keep authored Dart and original assets under version
control. A later edit should change the composition rather than requiring a
manual timeline operation.

For errors, run the same command with `--verbose`. `--keep-temp` retains the
capture sandbox. Advanced hosts can use `--renderer` for a custom renderer
factory or `--harness` for a complete custom Flutter test; the
[export guide](../guides/exporting-your-video.md) describes these escapes.

## Where to next

- [Asset evidence](../guides/asset-evidence.md): give an assistant source-bound observations.
- [Review a video](../guides/reviewing-a-video.md): inspect samples and verify output.
- [AI and MCP](../guides/ai-and-mcp.md): choose a provider or teach an external assistant.
