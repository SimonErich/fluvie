# Exporting your video

Pick what the render writes: an MP4, a GIF, an image sequence, or an
alpha-capable overlay. Set `Video.export` to one of the four modes and Fluvie
encodes that container. Here are all four:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-modes)" -->
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

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-mp4-quality)" -->
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

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-gif-fps)" -->
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

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-image-sequence)" -->
```dart
const Export.imageSequence(); // one PNG per frame, into the output directory
```

The sequence carries no audio. Each still is lossless, so the pipeline starts
from the exact captured pixels.

## Transparent overlay

`Export.transparent()` writes a WebM with an alpha channel, so the video can
layer over other footage. The captured RGBA alpha is preserved end to end:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-transparent)" -->
```dart
const Export.transparent(); // VP9 WebM with a yuva420p alpha plane
```

Reach for it when you render a lower-third, a logo sting, or a caption pass that
sits on top of a clip in another editor. An alpha-capable overlay carries no
audio. ProRes `.mov` with alpha is forthcoming; WebM ships today.

## A poster frame

`Video.poster` names a `Time`, and the render grabs that one frame as a still
thumbnail alongside the main output. Set it on the same `Video` as the export:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (export-poster)" -->
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

`fluvie render` captures a registered composition and encodes it without opening
the example app. The minimal call names a composition key and an output file:

```sh
fluvie render 01_hello_video --out hello.mp4
```

The flags map onto the export modes above:

```sh
fluvie render 01_hello_video --out reel.mp4 --aspect reels --quality high
fluvie render 01_hello_video --out clip.gif --format gif
fluvie render 01_hello_video --out frames/ --format imageSequence
fluvie render 01_hello_video --out overlay.webm --format transparent
fluvie render 01_hello_video --out hero.mp4 --poster 1.5s
```

The flags:

- `--out <file>` sets the output path. It is required.
- `--aspect <name>` picks the aspect: `reels`, `square`, `landscape`, or
  `portrait45`. With no `--aspect` the composition renders at its declared
  size; pass an aspect to re-frame it.
- `--quality <name>` picks the MP4 quality: `low`, `medium`, `high`, or `max`.
- `--format <name>` picks the export mode: `mp4`, `gif`, `imageSequence`, or
  `transparent`. It defaults to `mp4`.
- `--poster <time>` writes a poster still from a `Time` string, for example
  `1.5s`, `30f`, or `500ms`.

A bad enum value exits with code 64 and names the valid set, so a typo fails
fast rather than rendering the wrong thing. The other flags from earlier phases
stay: `--frames N` for a draft render, `--project <dir>`, `--ffmpeg <path>`,
`--no-cache`, `--keep-temp`, and `--verbose`.

To see every composition key you can render, run:

```sh
fluvie list
```

It prints one key per line.

## One determinism note

The video frames are byte-identical on every machine: the same input always
captures the same pixels. The encoded file is byte-identical per machine,
because FFmpeg builds differ. The encoder runs with bit-exact flags on a single
thread, so a given FFmpeg build always produces the same bytes from the same
frames. See [Determinism and caching](../advanced/determinism-and-caching.md)
for the full model.

## Where to next

- [Determinism and caching](../advanced/determinism-and-caching.md): why frames
  are byte-identical everywhere and encoded files are per-machine.
- [Templates](../advanced/templates.md): render one definition per data row,
  byte-identically.
- [Multi-aspect](../advanced/multi-aspect.md): one definition rendered to reels,
  square, landscape, and portrait.
