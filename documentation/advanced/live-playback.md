# Live playback and timeline introspection

A composition does not have to become a file to be useful. `LivePlayer` plays
a `Video` in a running app on a real clock, and `introspectTimeline` tells
you where everything on its timeline sits, without mounting a widget.

## Playing a Video live

`LivePlaybackController` is a wall-clock face for the frame clock. It maps
elapsed time to frame indexes; `LivePlayer` owns the ticker and delivers each
frame to the tree through the same per-frame rebuild path capture uses:

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (live-player)" -->
```dart
Widget playLive(Video video) {
  final playback = LivePlaybackController(fps: video.fps, totalFrames: video.totalFrames);
  playback.play();
  return LivePlayer(controller: playback, child: video);
}
```

There is exactly one clock. When the controller says frame 90, every animated
element renders frame 90. Pause it and the picture freezes; seek it and the
picture lands, no drift between what plays and what renders.

## The playback surface

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (playback-controls)" -->
```dart
Future<void> driveIt(LivePlaybackController playback) async {
  playback.play(); // free-run from the current frame
  playback.pause(); // freeze right here
  playback.seek(120); // land exactly on frame 120
  playback.hold(120); // land there and stay (back-navigation wants this)
  playback.rate = 1.5; // one-and-a-half speed, rebased without a jump
  await playback.playRange(120, 180); // play a segment, hold its last frame
}
```

Two details worth knowing:

- `seek` and `rate` rebase the clock at the current frame, so a playing video
  never jumps when you scrub or change speed.
- `playRange` returns a future that completes when the segment's last frame
  holds, or when something interrupts it. It never errors and never hangs.

Listen to `playback.frames` for per-frame notifications and to the controller
itself for state changes. The split keeps chrome from rebuilding sixty times
a second.

`LivePlayer` mounts `RenderMode.preview`, so wall-clock widgets and platform
views are allowed: nothing is being encoded. Determinism binds captures, not
previews.

## Reading the timeline without mounting it

`introspectTimeline` resolves a video's timing plan statically. Same resolver
the mounted `Video` runs, no widgets, no IO, same input same output:

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (introspection)" -->
```dart
void whereThingsAre(Video video, Anchor logo) {
  final introspection = introspectTimeline(video);
  final scene = introspection.scenes[1];
  debugPrint('scene 1 runs ${scene.span.start}..${scene.span.end}');

  final element = introspection.elementForAnchor(logo)!;
  debugPrint('the logo is alive ${element.window}');
  debugPrint('its entrance plays ${element.enterSpan}');
}
```

The introspection returns `FrameSpan` values (half-open frame ranges) for
every scene and every animated element: its alive-window, each animation's
absolute span, and `enterSpan`, the combined entrance an element plays to
come in as authored. Elements resolve by `Anchor` instance, by widget key,
or by the widget instances you walked yourself.

One boundary to respect: introspection walks the tree you declared, the same
way media pre-resolution does. An element created inside an opaque custom
widget's `build()` is invisible to it. Keep `.animate()` calls in constructor
data (scene children, plain layout widgets) and the walk sees everything.

## Where to next

- [The FrameBuilder escape hatch](frame-builder.md) reads the same frame
  clock from inside the tree.
- [Timeline orchestration](timeline-orchestration.md) places animations the
  introspector will happily report back to you.
- [Scenes and transitions](../guides/scenes-and-transitions.md) covers the
  boundaries the scene spans reflect.
