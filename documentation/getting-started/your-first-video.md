# Your first video

You describe what the video is. Fluvie computes when everything happens.
Lesson 01 is the smallest complete example: one scene, one background, one
animated title.

Start with two imports. Fluvie's `Animation` replaces Flutter's, so hide the
Flutter one:

<!-- code-excerpt "example/lib/lessons/01_hello_video.dart (imports)" -->
```dart
import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
```

Now the whole video:

<!-- code-excerpt "example/lib/lessons/01_hello_video.dart (video)" -->
```dart
Video lesson01Video() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
```

## What each line does

- `Video` is the root. `VideoSize.square` makes a 1080 by 1080 canvas at the
  default 30 fps.
- `poster: 1.seconds` names the frame that previews and thumbnails show.
- `Scene` holds 4 seconds of content. Its children sit on a centered canvas.
- `Background.gradient` fills the scene behind everything else.
- `.animate([...])` attaches motion to any widget. The fade and the pop both
  start when the scene starts; you never type a frame number.

## Render it

From the repo root:

```sh
dart run packages/fluvie_cli/bin/fluvie.dart render 01_hello_video --out build/01_hello_video.mp4
```

The CLI captures every frame, then FFmpeg encodes the MP4.

## Preview it

Open the example app and pick "Hello, video" in the lesson list. Scrub the
slider to step through frames; the timeline pane shows when each animation
plays.

## Where to next

- [Core concepts](core-concepts.md): Video, Scene, Time, animate, Defaults.
- [Timing and triggers](../guides/timing-and-triggers.md): make elements
  react to each other.
