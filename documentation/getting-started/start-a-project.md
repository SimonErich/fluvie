# Start a Fluvie project

`fluvie init` gets you started. It writes a starter video in real Flutter widget
code, ready to preview and render. Run it once:

```sh
dart pub global activate fluvie_cli
fluvie init
```

It is the one interactive command. It asks where to put things and offers a
sensible default, so most of the time you just press Enter. Pass `--yes` to take
every default with no prompts.

When it scaffolds the render harness (the default), it also turns on Fluvie's
lint rules (`fluvie_lints` via `custom_lint`), so a dangling anchor or a cyclic
trigger shows up in your IDE as you type, with a quick fix where one exists.
Skip the harness and you skip the lint wiring too.

## Outside a Flutter project

If you are not in a Flutter project, `fluvie init` offers to scaffold a minimal
one with `flutter create`, then adds the starter composition, a live preview, a
render harness, and a widget test:

```sh
fluvie init --dir my_reel --yes
cd my_reel
flutter pub get
```

You now have a project you can run, render, and test.

## Inside a Flutter project

Run `fluvie init` in a project that already has Flutter and it drops the starter
composition into `lib/videos/`, adds `fluvie` to your `pubspec.yaml` if it is
missing, and wires a render harness so `fluvie render` works:

```sh
fluvie init --yes        # or: fluvie init --name intro --path lib/videos/intro.dart
flutter pub get
```

Useful flags: `--name` sets the render key and file name, `--path` chooses the
file location, `--no-render` skips the harness (and with it the lint wiring),
and `--force` overwrites an existing file.

## The starter composition

A Fluvie video is real Flutter widget code. Two imports, then a `Video` of
`Scene`s. Fluvie's `Animation` replaces Flutter's, so hide the Flutter one:

<!-- code-excerpt "examples/gallery/lib/starter/starter_video.dart (imports)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
```

Here is the whole video: one square scene, a gradient background, and a title
that fades and pops in. You never type a frame number.

<!-- code-excerpt "examples/gallery/lib/starter/starter_video.dart (video)" -->
```dart
/// Builds the starter composition: a 4 second square clip with a title that
/// fades and pops in. You describe what the video is; Fluvie decides when
/// everything happens.
Video starterVideo() {
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

## Preview it

Run the project like any Flutter app and scrub the slider:

```sh
flutter run
```

`Video` has no wall clock; the preview drives the frame index for you.

## Render it

Render the composition to an MP4 by its key (the `--name` you chose, `starter` by
default):

```sh
fluvie render starter --out starter.mp4
```

The CLI captures every frame with `flutter test`, then FFmpeg encodes the file.
The first render downloads a pinned FFmpeg build for you.

## Test it

The scaffold includes a widget test that builds the video and pumps a frame:

```sh
flutter test
```

## Where to next

- [Your first video](your-first-video.md): a line-by-line tour of the starter.
- [Core concepts](core-concepts.md): Video, Scene, Time, animate, Defaults.
- [AI and MCP](../guides/ai-and-mcp.md): have an assistant write real Fluvie code.
