# Exporting your video

Pick what the render writes: an MP4, a GIF, an image sequence, or an
alpha-capable overlay. Set `Video.export` to one of the four modes and Fluvie
encodes that container. Here are all four:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-modes)" -->
```dart
Export sharable() => const Export.mp4(quality: Quality.max); // H.264 MP4, CRF 14
Export loopingThumb() => const Export.gif(fps: 12); // animated GIF at 12 fps
Export forCompositing() => const Export.imageSequence(); // one PNG per frame
Export overlay() => const Export.transparent(); // WebM with an alpha channel
```

With no `export`, a render writes an MP4 at the default quality. The rest of
this page covers the four modes, the poster frame, and the command-line
renderer.

## MP4 quality

`Export.mp4(quality:)` writes an H.264 MP4. The `quality` picks the encoder's
constant-rate factor (CRF), where a lower CRF means a bigger file and less
compression:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-mp4-quality)" -->
```dart
Export.mp4(quality: Quality.low), // CRF 28, smallest file, visible compression
Export.mp4(quality: Quality.medium), // CRF 23, a rough-cut trade-off
Export.mp4(quality: Quality.high), // CRF 18, the default for published videos
Export.mp4(quality: Quality.max), // CRF 14, near-lossless, the largest file
```

`Quality.high` is the default, so `const Export.mp4()` writes a published-grade
file. Reach for `Quality.low` for quick draft renders and `Quality.max` for an
archival master.

## GIF

`Export.gif(fps:)` writes an animated GIF. The `fps` samples the frames, since a
GIF rarely needs the full frame rate. A lower `fps` makes a smaller file:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-gif-fps)" -->
```dart
Export.gif(fps: 15), // the default sample rate
Export.gif(fps: 12), // a smaller, choppier loop
```

The encoder builds an optimized 256-color palette from your frames in one pass,
then maps the frames onto it with dithering, so a GIF keeps its color and stays
small. A GIF carries no audio.

## Image sequence

`Export.imageSequence()` writes one lossless PNG per frame, named
`frame_000000.png`, `frame_000001.png`, and so on. Reach for it when a
compositing pipeline downstream wants individual frames rather than a container:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-image-sequence)" -->
```dart
const Export.imageSequence(); // one PNG per frame, into the output directory
```

The sequence carries no audio. Each still is lossless, so the pipeline starts
from the exact captured pixels.

## Transparent overlay

`Export.transparent()` writes a WebM with an alpha channel, so the video can
layer over other footage. The captured RGBA alpha is preserved end to end:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-transparent)" -->
```dart
const Export.transparent(); // VP9 WebM with a yuva420p alpha plane
```

Reach for it when you render a lower-third, a logo sting, or a caption pass that
sits on top of a clip in another editor. An alpha-capable overlay carries no
audio. ProRes `.mov` with alpha is forthcoming; WebM ships today.

## A poster frame

`Video.poster` names a `Time`, and the render grabs that one frame as a still
thumbnail alongside the main output. Set it on the same `Video` as the export:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_14_snippets.dart (export-poster)" -->
```dart
Video exportedReel() => Video(
  size: VideoSize.reels,
  export: const Export.mp4(quality: Quality.max), // near-lossless, CRF 14
  poster: const Time.seconds(1.5), // the thumbnail frame
  scenes: [
    Scene.centered(
      duration: const Time.seconds(3),
      background: Background.color(const Color(0xFF0E1116)),
      child: const Text('Exported', style: TextStyle(fontSize: 72, color: Color(0xFFE6EDF3))),
    ),
  ],
);
```

The poster is a second output from the same frames, so it costs one extra
encode of one frame. Pick a `Time` that lands on a representative moment, for
example 1.5 seconds into a 3 second card.

## The command-line renderer

`fluvie render` captures a composition and encodes it, with no app to open. Point
it at the file:

```sh
fluvie render ./lib/my_video.dart
```

It calls the file's top-level `Video build()` using a cached harness outside
your project and encodes the frames. Output defaults to
`build/fluvie/my_video.mp4`, with the extension or directory chosen for the
authored export mode. Size, FPS, duration, quality, export mode, and poster come
from the `Video`; explicit flags override the authored choices:

```sh
fluvie render ./lib/my_video.dart --out reel.mp4 --aspect reels --quality high
fluvie render ./lib/my_video.dart --out clip.gif --format gif
fluvie render ./lib/my_video.dart --out frames/ --format imageSequence
fluvie render ./lib/my_video.dart --out overlay.webm --format transparent
fluvie render ./lib/my_video.dart --out hero.mp4 --poster 1.5s
```

The flags:

- `--out <file>` overrides the automatic output path. For image sequences it names a directory.
- `--entry <name>` names the top-level function returning the `Video`. It
  defaults to `build`.
- `--aspect <name>` picks the aspect: `reels`, `square`, `landscape`, or
  `portrait45`. With no `--aspect` the composition renders at its declared
  size; pass an aspect to re-frame it.
- `--quality <name>` picks the MP4 quality: `low`, `medium`, `high`, or `max`.
- `--format <name>` picks the export mode: `mp4`, `gif`, `imageSequence`, or
  `transparent`. With no flag, the authored `Video.export` wins; otherwise MP4 is the default.
- `--poster <time>` writes a poster still from a `Time` string, for example
  `1.5s`, `30f`, or `500ms`.

A bad enum value exits with code 64 and names the valid set, so a typo fails
fast rather than rendering the wrong thing. The rest: `--frames N` for a draft
render, `--project <dir>`, `--ffmpeg <path>`, `--keep-temp`, and `--verbose`.

## The frame cache

Managed file renders reuse captured frames by default. The CLI fingerprints
all project-local Dart (including imported helpers and parts outside `lib/`),
resolved dependency Dart, dependency resolution, discovered and declared
assets/fonts/shaders, explicit spec/renderer/harness inputs, SDK identity,
selected native tools, and export options. Editing a local input changes the
fingerprint instead of replaying an old frame under the same filename.

Project build/tool caches and generated adapter directories are excluded from
the scan. A target or custom renderer physically outside the selected project
disables frame caching because its external relative imports are not covered.
An explicit `--cache-key` enables caller-owned identity for those external inputs.

Use `--no-cache` when runtime network/generator data or external file sources
can change outside those declared local inputs:

```sh
fluvie render ./lib/my_video.dart --no-cache
```

Built-in AI authoring bypasses frame cache for the new composition. Programmatic
render hosts remain responsible for the cache identity of runtime data. When you
can identify that data reliably, include its version or content hash:

```sh
fluvie render ./lib/my_video.dart --cache-key catalog-sha256-v3
```

The key becomes part of the capture fingerprint; changing it invalidates frames
even if local source files did not change. Update it whenever remote, generated
or transitive external inputs change. It does not automatically track network
content. Use `--no-cache` when you cannot establish a reliable identity. Keys must
be nonempty, single-line strings of at most 4096 characters. Programmatic
`runRenderPipeline` accepts the corresponding `cacheKey` argument.

## Machine-readable output and receipts

Use `--machine` to follow a render from an agent or another program:

```sh
fluvie render ./lib/my_video.dart --machine
```

Standard output contains JSON lines: `progress` events name authoring, capture,
encoding, output verification, or finalization, and the final `artifact` event includes `filePath`
and `receiptPath` plus a compact artifact summary. Logs go to standard error. A normal render also retains a
`<output stem>.render.json` sidecar, such as
`build/fluvie/my_video.render.json`, with hashed inputs, source fingerprint,
selected toolchain, capture metadata, export options, and output bytes/SHA-256.
`output.media` summarizes the actual encoded container, codecs, dimensions,
pixel format, alpha, duration, declared frame count/rates, and audio tracks;
`output.probe` retains the ffprobe report. An authored poster includes its path,
size, and hash. Image sequences include sorted per-file hashes. A corrupt encoded
file fails verification before a success receipt is written.
Verification failures retain a `<output stem>.failed.render.json` diagnostic
receipt and exit unsuccessfully; they do not emit a successful artifact event.

This records what ran after the temporary workspace is removed. Normal encoded
renders compare available width, height, FPS, frame count, duration, codec,
container, audio-stream presence, alpha and pixel format against the resolved
capture intent. An audio stream does not prove an audible signal or its level.
Checks are scoped to the format: GIF timing is quantized and does not use an
unverified MP4 timing assumption; image sequences check count, dimensions and alpha.

Use `fluvie review ./lib/my_video.dart --render --strict-decode --json` to add a
complete decode check. It catches damaged encoded data beyond readable metadata
and costs an additional pass. Programmatic tooling can call `verifyOutput` with
`expected` intent and `strictDecode: true`. This establishes decodability;
metadata and decode verification do not judge the content of each picture or
creative fidelity. Use [review samples](reviewing-a-video.md)
and watch the output for visual and editorial decisions.


## Rendering by key

A project that still keeps a registry-based capture harness renders by key:

```sh
fluvie render 01_hello_video --out hello.mp4
```

That path is unchanged, and `--no-cache` still bypasses the cache for it. To see
every key such a project can render:

```sh
fluvie list
```

It prints one key per line. A file-based project needs no keys, so it needs no
`list`.

## Flutter widgets and platform services

Normal Flutter layout and custom widgets participate in the prepared composition
and capture clock. The default headless host runs in Flutter's test engine;
platform views and plugins that require a native application process need their
own integration. Static validation can check Dart types, but it cannot prove
that a native method channel is available during capture. Use a renderer suited
to those platform services when the composition needs them.


## Where to next

- [Templates](../advanced/templates.md): render one definition per data row.
- [Multi-aspect](../advanced/multi-aspect.md): one definition rendered to reels,
  square, landscape, and portrait.

## Custom render hosts

Use `--renderer <dart-file>` when a composition needs a custom rendering backend.
The file exposes `buildRenderer`, a function taking `RenderHostContext` and
returning a `VideoRenderer<File>` or a future of one. Set
`--renderer-entry <name>` to use another factory name.

`--harness <dart-file>` uses a complete custom Flutter test instead. It is an
advanced escape for an existing capture host and cannot be combined with
`--renderer`. The ordinary file workflow needs neither flag.

## Encoder controls

Beyond quality presets, `Export.mp4` accepts typed codec, encoder preset, pixel
format, and either CRF or bitrate. CRF and bitrate are mutually exclusive, and
invalid numeric values fail before encoding. Keep these settings in the authored
composition when they should be reproducible.

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (delivery-encoder)" -->
```dart
const settings = Export.mp4(
  codec: ExportCodec.h265,
  crf: 21,
  preset: EncoderPreset.fast,
  pixelFormat: ExportPixelFormat.yuv420p10le,
);
```
