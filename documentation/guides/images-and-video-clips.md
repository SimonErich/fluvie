# Images and video clips

Drop a photo into a scene with `Image`, and a video with `Clip`. Both are
Fluvie's own widgets, both animate with `.animate()`, and both are resolved
before the first frame so nothing pops in when it loads:

<!-- code-excerpt "examples/gallery/lib/lessons/05_images_and_clips.dart (image-asset)" -->
```dart
Align(
  alignment: const Alignment(0, -0.15),
  child: Image.asset(
    'assets/fixtures/swatch.png',
    fit: BoxFit.cover,
    frame: const PhotoFrame.polaroid(caption: 'Summer'),
  ).animate([Animation.kenBurns(zoom: 1.2)]),
),
```

That asset loads from your bundle, sits in a polaroid frame with a caption, and
zooms slowly with a Ken Burns move. Lesson 05 builds the whole scene.

## The hidden `Image` name

Fluvie defines its own `Image` (and `Clip`, `Animation`, `Tween`). The single
barrel import hides Flutter's versions, so an unprefixed `Image` is Fluvie's:

<!-- code-excerpt "examples/gallery/lib/lessons/05_images_and_clips.dart (imports-fluvie)" -->
```dart
import 'package:fluvie/fluvie.dart'; // Image and Clip are Fluvie's here
```

If a file also imports Flutter directly, hide the four shadowed names or import
Flutter under a prefix:

<!-- code-excerpt "examples/gallery/lib/lessons/05_images_and_clips.dart (imports-flutter)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
```

## Four ways to name an image

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (image-constructors)" -->
```dart
Image.asset('photos/me.png'),
Image.file('/tmp/frame.png'),
Image.memory(bytes),
Image.network('https://picsum.photos/seed/fluvie/800/800'),
```

A remote image resolves the same way an asset does. Fluvie fetches, decodes,
and caches it in the pre-resolve pass, then paints it synchronously:

<!-- code-excerpt "examples/gallery/lib/lessons/05_images_and_clips.dart (image-network)" -->
```dart
Widget remotePhoto() => Image.network(
  'https://picsum.photos/seed/fluvie/800/800',
  fit: BoxFit.cover,
).animate([Animation.slideFadeIn(), Animation.kenBurns(zoom: 1.2)]);
```

Only allowlisted hosts and schemes are fetched during a render. A disallowed
host raises a typed error that names it.

Native probing and decoding operate on staged local files. Their FFmpeg input
policy permits only the `file` protocol, so a local playlist cannot fetch remote
segments behind the loader's allowlist. If you call `FfmpegMediaTools` directly,
download permitted sources through your allowlisted loader before passing a
local path. Its low-level `run` method executes your own argument list and does
not add that policy for custom commands.

## Frames

A `PhotoFrame` is a decorative wrapper you pass to an element. The four styles are
`PhotoFrame.none`, `PhotoFrame.rounded`, `PhotoFrame.card`, and `PhotoFrame.polaroid`. The card and
polaroid styles carry one deterministic drop shadow; the polaroid takes an
optional caption under the image. The element rewraps the frame around itself,
so you write the style once on the `frame:` parameter.

## Clips

`Clip` embeds a video. Pick the portion you want with `trim`, in source time:

<!-- code-excerpt "examples/gallery/lib/lessons/05_images_and_clips.dart (clip)" -->
```dart
Align(
  alignment: const Alignment(0, 0.62),
  child: SizedBox(
    width: 360,
    height: 240,
    child: Clip.asset(
      'assets/fixtures/clip_1s.mp4',
      fit: BoxFit.cover,
      trim: 0.2.seconds.to(0.8.seconds),
    ).animate([Animation.fadeIn(delay: 0.3.seconds)]),
  ),
),
```

### Clip audio

The clip's `audio` parameter declares its audio policy (`ClipAudio.included` or
`ClipAudio.muted`); the audio pipeline reads it when it mixes the render's
soundtrack. `ClipAudio.included` carries a `volume`, a `fadeIn` and a
`fadeOut`. Both ramps are anchored to the clip's own window rather than to the
source file: the fade-in starts where the clip starts, and the fade-out *ends*
where the clip stops being shown, so a half-second ramp on a clip that ends at
five seconds begins at four and a half.

`scaledBy` multiplies a clip's gain while preserving automation, fades, and
mute. It rejects negative or non-finite gain values:

<!-- code-excerpt "examples/gallery/lib/snippets/authoring_snippets.dart (scale-clip-audio)" -->
```dart
/// Change a clip's gain without discarding its original fade policy.
ClipAudio quietClip() => ClipAudio.included(
  volume: 0.8,
  fadeIn: 0.2.seconds,
  fadeOut: 0.3.seconds,
).scaledBy(0.5);
```


### Four ways to name a clip

The clip menu mirrors the image menu:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (clip-constructors)" -->
```dart
Clip.asset('assets/fixtures/clip_1s.mp4'),
Clip.file('/captures/take_3.mp4'),
Clip.memory(bytes, debugLabel: 'imported.mp4'),
Clip.network(Uri.parse('https://cdn.example.com/promo.mp4')),
```

`Clip.file` reads a video on disk; the path must end in `.mp4`, `.mov`, or
`.webm`. `Clip.memory` takes raw encoded bytes that never touched disk, for
example a file imported in the browser. Give it a `debugLabel` with the file
name (`imported.mp4`): the label is how Fluvie classifies the bytes as a clip,
and it names the source in errors. A memory clip's embedded audio joins the
mix like any other clip's; the bytes materialize to a temp file the encoder
reads.

Fluvie maps the composition frame to a source frame by flooring, so a slow
source under a fast composition holds frames instead of skipping. The trim
bounds are exact: a clip never reads past its window.

### Slow motion, fast motion, and rewind

`speed` sets the playback rate. `1` is source speed, `0.5` is half, `2` is
double, and a negative rate plays the trim backwards from its last frame:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (clip-speed)" -->
```dart
Clip.asset('assets/fixtures/clip_1s.mp4', speed: 0.5),
Clip.asset('assets/fixtures/clip_1s.mp4', speed: 2),
Clip.asset('assets/fixtures/clip_1s.mp4', speed: -1),
```

The rate scales how much source time each composition second spends, so a clip
shown for three seconds at `2` reads six seconds of source. The trim still
bounds it: a fast clip that runs out holds its last frame rather than reading
past the trim.

The embedded audio is retimed with the picture, so the two stay together. A
**reversed** clip is the exception: it plays no audio at all. Nothing in the
encoder graph plays a stream backwards, and forward audio under backwards
picture is worse than silence. Declare an `Audio` track if a rewind needs
sound.

Native mobile, desktop, and browser renderers support positive-speed clip audio
retiming, including the supported speed-ramp shapes. Reversed clips remain
silent. See the mobile rendering guide for codec and mixer limits.

A rate of `0` is refused rather than treated as a freeze frame: it would
advance no source frames at all, which is an `Image` with a `poster`.

### Variable-frame-rate footage

The default native CLI resolver uses source presentation timestamps for trim,
speed and resampling. It preserves irregular display intervals and the complete
final picture interval instead of multiplying seconds by average FPS. A custom
decoder can supply the same facts through `ClipTimelineResolver` and
`MediaTimeline`.

Browser and mobile decoders without that timeline interface fall back to reported
FPS. For those hosts, normalize irregular footage to a constant rate when exact
source timing matters:

```sh
ffmpeg -i input.mp4 -vf fps=30 -c:v libx264 -crf 18 -c:a aac constant_30fps.mp4
```

Keep the original source and the conversion command for a replayable workflow.
The command is for opaque footage; choose an alpha-capable codec for transparent
media. Keep the original for native hosts that already preserve its presentation
timeline.


### Transparent clips

A WebM/VP9 clip with an alpha channel composites over whatever is behind it, so
you can drop a cut-out subject straight onto a background. Point `Clip.asset` at
the `.webm` the way you would at an `.mp4`; nothing else changes.

Two facts about the format are handled for you.

WebM stores no frame count and no per-stream duration, so a plain probe reports
neither. Fluvie runs a second `-count_frames` pass to get the exact count, and
falls back to duration times frame rate if that pass reports nothing. The extra
pass decodes every video packet, so it runs only for a container that stored no
count of its own. An MP4 never pays it.

VP9 stores alpha as a second coded layer that only the `libvpx-vp9` decoder
reads. FFmpeg's native `vp9` decoder silently drops it, and the clip composites
over black. Fluvie selects `libvpx-vp9` for a VP9 stream tagged `ALPHA_MODE=1`;
an opaque VP9 clip stays on the native decoder, which is much faster.

Export a transparent clip with alpha intact, or the layer will not be there to
read:

```sh
ffmpeg -i in.mov -c:v libvpx-vp9 -pix_fmt yuva420p out.webm
```

For a transparent clip, use VP9/WebM or ProRes. H.264 cannot carry alpha, so an
`.mp4` never composites over what is behind it.

## Pre-resolution

The reason media never pops in is the pre-resolve pass. Before frame 0, Fluvie
walks your scenes, gathers every `Image` and `Clip` source, and resolves them
all: it fetches bytes, content-hashes them, decodes images to GPU images, and
extracts the clip frames it will need. During the frame loop every read is a
synchronous cache lookup, so no frame ever waits on IO.

That is what makes a render reproducible. Same sources in, same frames out.

## Where to next

- [Live playback](../advanced/live-playback.md): `PreviewMediaScope`, which runs
  that same pre-pass in a preview so your clips play while you author them.
- [Text and typography](text-and-typography.md): `Text`, `Typewriter`, and
  `Counter`, the other elements you compose with media.
- [Scenes and transitions](scenes-and-transitions.md): the scene-level shared
  elements an `Image` can join with `shared:`.
