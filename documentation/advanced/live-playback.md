# Live playback and timeline introspection

A composition does not have to become a file to be useful. `VideoPreview` owns
media preparation, playback, scrubbing, fitting, and its clock. Use it when you
want to show an authored composition inside your own Flutter app:

<!-- code-excerpt "examples/gallery/lib/snippets/authoring_snippets.dart (video-preview)" -->
```dart
/// Embeds the authored composition in your own Flutter app.
Widget preview() => const VideoPreview.builder(builder: build);
```

The builder rebuilds authored code after hot reload while preserving playback
position. Place the preview in a bounded layout such as a `Scaffold` body.
Pass a `PreviewAudioController` when the host provides audio; the CLI configures
its browser audio automatically. Browser sound starts after a user gesture.

For lower-level hosting, `LivePlayer` connects a caller-owned controller to the
frame clock. `introspectTimeline` reports timeline positions without mounting a
widget.

## Playing a Video live

`LivePlaybackController` is a wall-clock face for the frame clock. It maps
elapsed time to frame indexes; `LivePlayer` owns the ticker and delivers each
frame to the tree through the same per-frame rebuild path capture uses. Create
the controller once in `initState`, update it when the timeline changes, and
dispose it with its owning `State`:

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (live-player)" -->
```dart
class PlayingVideo extends StatefulWidget {
  const PlayingVideo({required this.video, this.previewMedia = false, super.key});

  final Video video;
  final bool previewMedia;

  @override
  State<PlayingVideo> createState() => _PlayingVideoState();
}

class _PlayingVideoState extends State<PlayingVideo> {
  late LivePlaybackController playback;

  @override
  void initState() {
    super.initState();
    playback = createPlayback();
  }

  LivePlaybackController createPlayback() =>
      LivePlaybackController(fps: widget.video.fps, totalFrames: widget.video.totalFrames)..play();

  @override
  void didUpdateWidget(PlayingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.fps != widget.video.fps ||
        oldWidget.video.totalFrames != widget.video.totalFrames) {
      playback.dispose();
      playback = createPlayback();
    }
  }

  @override
  void dispose() {
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LivePlayer(
    controller: playback,
    child: widget.previewMedia ? PreviewMediaScope(composition: widget.video) : widget.video,
  );
}
```

There is exactly one frame clock. When the controller says frame 90, authored
animations render frame 90. Pause it and the picture freezes; seek it and the
picture lands at that authored position.

## Playing clips in a preview

`fluvie preview ./lib/my_video.dart` wires this for you. Reach for the rest of this
section only when you host a `LivePlayer` yourself, in an app of your own.

A player alone gives a `Clip` no frames to paint. A render prepares metadata and
the needed clip pictures before each capture, and paint reads that cache synchronously. A plain
preview runs no pre-pass, so a clip shows a labelled placeholder instead.

Wrap the composition in a `PreviewMediaScope` to run the same pre-pass:

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (preview-media)" -->
```dart
Widget playLiveWithMedia(Video video) => PlayingVideo(video: video, previewMedia: true);
```

The scope prepares the composition's media and mounts its resolver. Clip frames
are requested as needed. The painter uses the same timeline and resampling
logic as capture. Exact variable-rate timing depends on the selected decoder;
the CLI's native bridge supplies source presentation timestamps.

Three things to know:

- **Preview resolution is bounded.** `maxClipEdge` scales raster decoding
  (720 by default) while layout, source timing, trims, and resampling keep the
  original facts. Pass `null` for full source resolution. `VideoPreview` uses an
  on-demand scrub cache rather than retaining an entire movie's full-size frames.
- **Preparation is asynchronous.** The player shows preparation before playback
  and reports media failures visibly through `onError`. Seeking requests source
  frames for the new position; it does not decode the whole movie first.
- **Your host chooses its decoder.** The CLI configures native tools and its local
  browser bridge automatically. An independently hosted web preview can pass
  `clipDecoder:`; a native host can select its media resolver. With no usable
  decoder, lower-level media scopes report the cause and show fallback content.


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

Natural playback holds the final picture while its complete frame interval
finishes. A one-picture video still plays for `1 / fps` seconds. The integer
`frame` identifies the picture being painted; continuous `position` includes
that final interval and drives preview audio. `isComplete` becomes true only
when the whole duration has elapsed. Seeking to the final picture leaves that
interval available to play.

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
by the widget instances you walked yourself, or by spec element id through
`elementById` (a deck built from a spec tags each identified element; a
widget-authored deck opts in by wrapping an element in `SpecElementId`).

One boundary to respect: introspection walks the tree you declared, the same
way media pre-resolution does. An element created inside an opaque custom
widget's `build()` is invisible to it. Keep `.animate()` calls in constructor
data (scene children, plain layout widgets) and the walk sees everything.

## Dynamic subtrees with LocalMotionScope

A `Video` resolves its plan once, so its element set must stay stable across
frames. Live consumers sometimes want the opposite: content that appears
mid-playback and animates in right then. Wrap the dynamic part in a
`LocalMotionScope`:

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (local-motion-scope)" -->
```dart
Widget lateArrival({required bool revealed}) => LocalMotionScope(
  child: revealed ? const Text('surprise!').animate([Animation.fadeIn()]) : const SizedBox.shrink(),
);
```

Below the scope, `.animate()` elements resolve immediately and locally
against the nearest time scope. They can mount and unmount whenever they
like. The trade: cross-element triggers (`Trigger.whenEnds`, `whenStarts`)
and `Trigger.beat` need the composition plan, so they are unavailable
inside. `Trigger.previous` chains on one element still work.

## Live placement overrides for editors

A canvas editor drags elements many times a second. Rebuilding the
composition per pointer move would remount players and reset element state,
so `PlacedOverrides` takes the other route: it mounts per-element
`Placement` replacements over a composition that stays exactly as built.

<!-- code-excerpt "examples/gallery/lib/snippets/live_playback_snippets.dart (placed-overrides)" -->
```dart
Widget dragPreview(Video video, Map<String, Placement> live, LivePlaybackController held) =>
    LivePlayer(
      controller: held,
      child: PlacedOverrides(overrides: live, child: video),
    );
```

Each `Placed` element that carries an `id` (the spec's element ids flow
through automatically) reads its own entry and re-lays out; elements
without an entry never rebuild. On release the editor writes the real
`transform` and clears the map. The overrides are a preview surface only:
saving, digests, and renders read the document, never this scope.

## Where to next

- [The FrameBuilder escape hatch](frame-builder.md) reads the same frame
  clock from inside the tree.
- [Timeline orchestration](timeline-orchestration.md) places animations the
  introspector will happily report back to you.
- [Scenes and transitions](../guides/scenes-and-transitions.md) covers the
  boundaries the scene spans reflect.
