# Images and video clips

Drop a photo into a scene with `Image`, and a video with `Clip`. Both are
Fluvie's own widgets, both animate with `.animate()`, and both are resolved
before the first frame so nothing pops in when it loads:

<!-- code-excerpt "example/lib/lessons/05_images_and_clips.dart (image-asset)" -->
```dart
Align(
  alignment: const Alignment(0, -0.15),
  child: Image.asset(
    'assets/fixtures/swatch.png',
    fit: BoxFit.cover,
    frame: const Frame.polaroid(caption: 'Summer'),
  ).animate([Animation.kenBurns(zoom: 1.2)]),
),
```

That asset loads from your bundle, sits in a polaroid frame with a caption, and
zooms slowly with a Ken Burns move. Lesson 05 builds the whole scene.

## The hidden `Image` name

Fluvie defines its own `Image` (and `Clip`, `Animation`, `Tween`). The single
barrel import hides Flutter's versions, so an unprefixed `Image` is Fluvie's:

<!-- code-excerpt "example/lib/lessons/05_images_and_clips.dart (imports-fluvie)" -->
```dart
import 'package:fluvie/fluvie.dart'; // Image and Clip are Fluvie's here
```

If a file also imports Flutter directly, hide the four shadowed names or import
Flutter under a prefix:

<!-- code-excerpt "example/lib/lessons/05_images_and_clips.dart (imports-flutter)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Image;
```

## Four ways to name an image

<!-- code-excerpt "example/lib/snippets/phase_08_snippets.dart (image-constructors)" -->
```dart
Image.asset('photos/me.png'),
Image.file('/tmp/frame.png'),
Image.memory(bytes),
Image.network('https://picsum.photos/seed/fluvie/800/800'),
```

A remote image resolves the same way an asset does. Fluvie fetches, decodes,
and caches it in the pre-resolve pass, then paints it synchronously:

<!-- code-excerpt "example/lib/lessons/05_images_and_clips.dart (image-network)" -->
```dart
Widget remotePhoto() => Image.network(
  'https://picsum.photos/seed/fluvie/800/800',
  fit: BoxFit.cover,
).animate([Animation.slideFade(), Animation.kenBurns(zoom: 1.2)]);
```

Only allowlisted hosts and schemes are fetched during a render. A disallowed
host raises a typed error that names it.

## Frames

A `Frame` is a decorative wrapper you pass to an element. The four styles are
`Frame.none`, `Frame.rounded`, `Frame.card`, and `Frame.polaroid`. The card and
polaroid styles carry one deterministic drop shadow; the polaroid takes an
optional caption under the image. The element rewraps the frame around itself,
so you write the style once on the `frame:` parameter.

## Clips

`Clip` embeds a video. Pick the portion you want with `trim`, in source time:

<!-- code-excerpt "example/lib/lessons/05_images_and_clips.dart (clip)" -->
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

## Pre-resolution and determinism

The reason media never pops in is the pre-resolve pass. Before frame 0, Fluvie
walks your scenes, gathers every `Image` and `Clip` source, and resolves them
all: it fetches bytes, content-hashes them, decodes images to GPU images, and
extracts the clip frames it will need. During the frame loop every read is a
synchronous cache lookup, so no frame ever waits on IO.

That is what makes a render reproducible. Same sources in, same frames out.

## Where to next

- [Text and typography](text-and-typography.md): `Text`, `Typewriter`, and
  `Counter`, the other elements you compose with media.
- [Determinism and caching](../advanced/determinism-and-caching.md): how
  pre-resolution and the content-hash cache make renders reproducible.
- [Scenes and transitions](scenes-and-transitions.md): the scene-level shared
  elements an `Image` can join with `shared:`.
