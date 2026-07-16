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

The clip's `audio` parameter declares its audio policy (`ClipAudio.included` or
`ClipAudio.muted`); the audio pipeline reads it when it mixes the render's
soundtrack.

Fluvie maps the composition frame to a source frame by flooring, so a slow
source under a fast composition holds frames instead of skipping. The trim
bounds are exact: a clip never reads past its window.

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
