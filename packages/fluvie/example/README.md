# Fluvie examples

The full, runnable examples live in the workspace `example/` app: twelve lessons
(`example/lib/lessons/01_hello_video.dart` through `12_the_kitchen_sink.dart`)
plus a scrubbable inspector. Each lesson is one complete, readable `Video`.

The smallest one, lesson 01:

```dart
import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

Video helloVideo() => Video(
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
```

Render it with the `fluvie_cli` headless renderer:

```sh
fluvie render 01_hello_video --out hello.mp4
```

See the [documentation](https://github.com/SimonErich/fluvie/tree/main/documentation)
for the guides and the reference.
