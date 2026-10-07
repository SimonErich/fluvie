# FAQ

The questions a new user asks first. Each answer is short and links to the page
that goes deeper. If you just want to render something, start here:

```sh
fluvie render ./lib/my_video.dart --out out.mp4
```

From a clone of this repo, render a lesson by its key instead, because the
gallery keeps a registry:

```sh
dart run packages/fluvie_cli/bin/fluvie.dart render 01_hello_video --out build/01.mp4
```

## Will my renders look the same each time?

In capture mode the frame is the only clock. Fluvie prepares required resources
asynchronously before painting each frame; paint reads prepared values without
wall-clock timing. This makes authored timing suitable for caching and golden
tests when the inputs are stable. Effects draw their randomness from seeded `noise(seed)` and `random(seed)`,
so a given seed reproduces the same sequence. Fluvie does not guarantee
byte-identical output across machines or encoders.

## Do I need FFmpeg?

Fluvie uses FFmpeg for native encoding, and the CLI provisions its tools
automatically when needed. You can also put compatible tools on PATH or pass
`--ffmpeg <path>` to the CLI.

Fluvie invokes FFmpeg with an argument list, never a shell string. Its standard
encode plan strips metadata and requests bit-exact, single-threaded encoding to
reduce avoidable variation. Codec availability depends on the selected FFmpeg
build; `fluvie doctor --json` reports its common encoders and decoders.

## Why does the same render produce a different MP4 on another machine?

The encoded file depends on the FFmpeg build, codec, options, input bytes and
capture environment, including Flutter's rasterizer and fonts. Keeping those
fixed reduces variation, but the flags do not guarantee identical files for
every codec or custom renderer. Across machines the bytes can differ even when
the picture looks the same. Compare receipts to identify changed inputs. See
[Exporting your video](../guides/exporting-your-video.md).

## My rendered text shows up as solid boxes. Why?

That is Flutter's Ahem test font, which draws every glyph as a filled box, so a
word looks like one bar. It means the real fonts were not loaded before the
frames were captured. The managed CLI host loads the project's declared fonts
and packaged fallback before capture, including server renders that use this
host. An arbitrary API deployment, Docker image or custom render host is not
automatically covered by that setup. If you host `renderVideo` yourself, load
the app fonts and pass
`defaultFontFamily` before you render.

## Should I render with Impeller?

Only when an effect needs it. Impeller is Flutter's current renderer, and it
draws shaders, grain, and blend modes differently from the default tester
backend. An ordinary render does not use it:

```sh
fluvie render ./lib/my_video.dart --out out.mp4 --enable-impeller
```

The flag passes `--enable-impeller` to `flutter test`, so the capture rasterizes
with Impeller. Reach for it when a shader or a blend mode looks wrong in the
encoded file, and leave it off otherwise.

## How do I watch it while I work?

```sh
fluvie preview ./lib/my_video.dart
```

Edit the file, save, and the preview redraws. The default starts a browser preview
and prints its URL. A local authenticated bridge uses native FFmpeg to decode
clips and audio, including source codecs the browser cannot decode itself. Pass
`-d chrome` to open Chrome automatically, or choose an installed desktop device
with `-d linux`, `-d macos`, or `-d windows`.

## What can I render today?

Text, images, video clips, charts, code and terminal blocks, Markdown,
annotations, audio, and captions. Multi-aspect and data-driven templates ship.
Three element types (`Mermaid`, `WebView`, `Html`) are documented but their live
transport is deferred: see the next answer.

## What is the snapshot deferral?

`Mermaid`, `WebView`, and `Html` rasterize an external source (a Mermaid
diagram, a web page, an inline HTML document) once before the frame loop, then
paint the cached image every frame. The element types and their painting are part of
v1, but the live headless-Chrome transport that captures the source is deferred.

They are marked `@experimental`. To use them you inject a `SnapshotService` that
provides the rasterized bytes; without one, resource preparation fails with an
error naming the missing `SnapshotService`. Their tests carry the `snapshot` tag and run
only where a live renderer is configured. See
[Diagrams and web pages](../guides/diagrams-and-webviews.md).

## How do I add a golden?

Goldens render through Alchemist at a fixed fps, a fixed seed, and DPR 1.0. CI
goldens use the Ahem font and run everywhere; platform goldens use bundled fonts
and run on the Linux baseline.

Write the test, then generate the baseline and review the PNG before committing:

```sh
flutter test --update-goldens --tags golden
```

Tag the test `golden`. A plain `melos run test` excludes goldens; `melos run
test:goldens` runs them. See [Testing guide](../contributing/testing.md).

## Where do audio and captions come from?

Audio comes from `Audio.music` and `Audio.sfx` on `Video.audio`. The encoder
mixes the tracks under the frames, and a beat pre-pass analyses the music before
frame 0 so `Trigger.beat` resolves deterministically.

Captions come from `Captions.fromSrt`, `Captions.fromVtt`, or `Captions.words`.
SRT and VTT files are parsed before frame 0; `words` carries inline, per-word
timed cues. See [Audio and captions](../guides/audio-and-captions.md).

## How do I make an element react to another?

Name the first element's timeline with an `Anchor`, then trigger the second off
it:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (trigger-after)" -->
```dart
const Text('Then me', style: _line).animate([
  Animation.slideFadeIn(at: Trigger.whenEnds(intro)),
]);
```

`intro` is an `Anchor` on the first element. Move the first element's timing and
the second follows. See [Timing and triggers](../guides/timing-and-triggers.md).

## How do the imports work?

`package:fluvie/fluvie.dart` is the only authoring entry. It exports the surface
you type inside a `Video`, including `Image`, `Animation`, `Tween`, and `Clip`,
which share names with Flutter's. The render pipeline lives on a second barrel,
`package:fluvie/rendering.dart`; see [the rendering surface](rendering-surface.md).
You still import Flutter for the widgets you use, with a `hide` so Fluvie's
versions win:

<!-- code-excerpt "examples/gallery/lib/lessons/01_hello_video.dart (imports)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
```

The four-name `hide` list resolves the shadow once; the composition `fluvie init`
scaffolds opens with it. If you need a hidden Flutter type, import it with a prefix
(`import 'package:flutter/widgets.dart' as flutter;`). `src/` stays private,
so you never import an internal path. The `no_src_import` lint enforces this.

## Where do I report a bug or a confusing API?

Open an issue with the bug-report template. If a public member's intended
behavior is unclear, flag it: the docs are meant to make every public member
legible. See [Contributing overview](../contributing/overview.md).

## Where to next

- [Cheatsheet](cheatsheet.md): the whole surface on one page.
- [Migration](migration.md): old names mapped to new.
