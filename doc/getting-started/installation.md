# Installation

> **Add Fluvie to your Flutter project**

This guide walks you through adding Fluvie to your project and configuring it for your needs.

## Table of Contents

- [Requirements](#requirements)
- [Adding the Package](#adding-the-package)
- [Import Statements](#import-statements)
- [Choosing an API](#choosing-an-api)
- [Verifying Installation](#verifying-installation)

---

## Requirements

### Flutter Version

Fluvie requires:

- **Flutter SDK:** 3.16.0 or higher
- **Dart SDK:** 3.2.0 or higher

Check your version:

```bash
flutter --version
```

### Platform Requirements

| Platform | Additional Requirements |
|----------|------------------------|
| Desktop | FFmpeg installed in PATH |
| Web | Server with CORS headers |
| Mobile | FFmpegKit dependency |

---

## Adding the Package

### From pub.dev

Add Fluvie to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### From Git (Latest Development)

For the latest features (may be unstable):

```yaml
dependencies:
  fluvie:
    git:
      url: https://github.com/simonerich/fluvie.git
      ref: main
```

### From Local Path

If you've cloned the repository:

```yaml
dependencies:
  fluvie:
    path: ../path/to/fluvie
```

---

## Import Statements

Fluvie provides two main entry points:

### Declarative API (Recommended)

For most use cases, use the declarative API:

```dart
import 'package:fluvie/declarative.dart';
```

This gives you access to:
- `Video` - High-level scene-based composition
- `Scene` - Time-bounded sections
- `AnimatedText`, `AnimatedProp` - Easy animations
- All layout widgets (`VStack`, `VColumn`, etc.)
- All effects and helpers

### Full API

For low-level control or advanced use cases:

```dart
import 'package:fluvie/fluvie.dart';
```

This gives you everything, including:
- `VideoComposition` - Low-level composition root
- `RenderService` - Direct render control
- Domain models (`RenderConfig`, etc.)
- Encoding services

### Specific Imports

For minimal imports:

```dart
// Just the declarative widgets
import 'package:fluvie/src/declarative/core/video.dart';
import 'package:fluvie/src/declarative/core/scene.dart';

// Just the presentation layer
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
```

---

## Choosing an API

### Declarative API

**Use when:**
- Building Spotify Wrapped-style videos
- Creating scene-based compositions
- Using pre-built animations and effects
- Rapid prototyping

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90,
      background: Background.gradient(
        colors: {0: Colors.purple, 90: Colors.blue},
      ),
      children: [
        VCenter(
          child: AnimatedText.slideUpFade('Welcome!'),
        ),
      ],
    ),
  ],
)
```

### Full API (VideoComposition)

**Use when:**
- Need frame-level control
- Building custom rendering pipelines
- Integrating with existing state management
- Creating reusable animation systems

```dart
import 'package:fluvie/fluvie.dart';

VideoComposition(
  fps: 30,
  durationInFrames: 90,
  width: 1920,
  height: 1080,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      return Container(
        color: Color.lerp(Colors.purple, Colors.blue, progress),
        child: Center(
          child: Opacity(
            opacity: progress,
            child: Text('Welcome!'),
          ),
        ),
      );
    },
  ),
)
```

---

## Verifying Installation

Create a simple test to verify everything is working:

### 1. Create a Test Widget

```dart
// lib/video_test.dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class VideoTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 800,
      height: 600,
      scenes: [
        Scene(
          durationInFrames: 60,
          background: Background.solid(Colors.blue),
          children: [
            VCenter(
              child: AnimatedText.fadeIn(
                'Fluvie Works!',
                style: TextStyle(
                  fontSize: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

### 2. Add to Your App

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'video_test.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(child: VideoTest()),
    ),
  ));
}
```

### 3. Run the App

```bash
flutter run
```

You should see a blue background with "Fluvie Works!" fading in.

### 4. Check FFmpeg (Optional)

Verify FFmpeg is available for rendering:

```dart
import 'package:fluvie/fluvie.dart';

void checkFFmpeg() async {
  final diagnostics = await FFmpegChecker.check();

  if (diagnostics.isAvailable) {
    print('FFmpeg ready: ${diagnostics.providerName}');
  } else {
    print('FFmpeg not found: ${diagnostics.errorMessage}');
    print(diagnostics.installationInstructions);
  }
}
```

---

## Common Issues

### "Package not found" Error

Make sure you ran `flutter pub get`:

```bash
flutter pub get
```

### Import Errors

If imports don't resolve, try:

```bash
flutter clean
flutter pub get
```

### Version Conflicts

If you get dependency conflicts, check for compatible versions:

```bash
flutter pub deps
```

---

## Next Steps

1. **[FFmpeg Setup](ffmpeg-setup.md)** - Configure video encoding
2. **[First Video](first-video.md)** - Build your first complete video

---

## Related Documentation

- [Platform Setup](../platform_setup/overview.md) - Platform-specific configuration
- [Architecture](../concept/architecture.md) - How Fluvie works
