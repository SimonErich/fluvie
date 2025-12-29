# Fluvie

[![pub package](https://img.shields.io/pub/v/fluvie.svg)](https://pub.dev/packages/fluvie)
[![CI](https://github.com/simonerich/fluvie/actions/workflows/ci.yml/badge.svg)](https://github.com/simonerich/fluvie/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/simonerich/fluvie/branch/main/graph/badge.svg)](https://codecov.io/gh/simonerich/fluvie)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter package for **programmatic video generation** using declarative widgets and FFmpeg. Create animated videos from Flutter widgets with frame-level control

**[🌐 Visit fluvie.dev](https://fluvie.dev)** | [📖 API Docs](https://simonerich.github.io/fluvie/) | [🎨 Examples](example/lib/gallery) | [🤖 MCP Server](https://mcp.fluvie.at)

## Features

- **Declarative Video Composition** - Use familiar Flutter widgets to define video content
- **Frame-Perfect Rendering** - Precise control over timing and animations
- **Layer System** - Z-indexed layers with time-based visibility and fade transitions
- **Audio Support** - Background music, audio tracks with trim and fade
- **Cross-Platform** - Desktop (Linux, macOS, Windows) and Web support
- **Pluggable FFmpeg** - Use native FFmpeg or WASM for web

## Quick Start

```dart
import 'package:fluvie/fluvie.dart';

// Define your composition
final composition = VideoComposition(
  fps: 30,
  durationInFrames: 150, // 5 seconds
  width: 1920,
  height: 1080,
  child: LayerStack(
    children: [
      // Background layer
      Layer.background(
        fadeInFrames: 15,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
          ),
        ),
      ),
      // Animated text
      Layer(
        id: 'title',
        startFrame: 30,
        endFrame: 120,
        fadeInFrames: 15,
        fadeOutFrames: 15,
        child: Center(
          child: TimeConsumer(
            builder: (context, frame, progress) {
              return Opacity(
                opacity: progress,
                child: Text(
                  'Hello Fluvie!',
                  style: TextStyle(fontSize: 72, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    ],
  ),
);
```

## Installation

Add `fluvie` to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.1.0
```

### Requirements

#### 1. Impeller Renderer (Required)

**⚠️ IMPORTANT**: Fluvie requires Flutter's **Impeller renderer** for proper video rendering. The Skia renderer will cause black backgrounds and visual artifacts in exported videos.

**Enable Impeller when running your app:**

```bash
# For all platforms
flutter run --enable-impeller

# For specific platform
flutter run -d macos --enable-impeller
flutter run -d linux --enable-impeller
flutter run -d windows --enable-impeller
```

**For VS Code debugging**, add to your `.vscode/launch.json`:

```json
{
  "configurations": [
    {
      "name": "Fluvie (Impeller)",
      "request": "launch",
      "type": "dart",
      "args": ["--enable-impeller"]
    }
  ]
}
```

**Note**: Impeller is enabled by default on iOS (Flutter 3.10+), but requires the `--enable-impeller` flag on Android and all desktop platforms.

Fluvie will automatically detect if Skia is being used and display a prominent warning dialog.

#### 2. FFmpeg Setup

Fluvie requires FFmpeg for video encoding.

**Linux:**
```bash
sudo apt install ffmpeg
```

**macOS:**
```bash
brew install ffmpeg
```

**Windows:**
Download from [ffmpeg.org](https://ffmpeg.org/download.html) and add to PATH.

**Web:**
Include in your `web/index.html`:
```html
<script src="https://unpkg.com/@ffmpeg/ffmpeg@0.12.6/dist/umd/ffmpeg.js"></script>
<script src="https://unpkg.com/@ffmpeg/util@0.12.1/dist/umd/util.js"></script>
```

Configure your server with required headers:
```
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

## Core Concepts

### VideoComposition

The root widget that defines video dimensions, frame rate, and duration:

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300, // 10 seconds
  width: 1920,
  height: 1080,
  child: YourContent(),
)
```

### Sequence

Time-bounded content blocks:

```dart
Sequence(
  startFrame: 0,
  durationInFrames: 90, // 3 seconds
  child: IntroScene(),
)
```

### TimeConsumer

Access the current frame for animations:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current frame number
    // progress: 0.0 to 1.0 within parent sequence
    return Transform.translate(
      offset: Offset(progress * 100, 0),
      child: MyWidget(),
    );
  },
)
```

### Layer & LayerStack

Video-specific layers with time-based visibility:

```dart
LayerStack(
  children: [
    Layer.background(child: Background()),
    Layer(
      startFrame: 30,
      endFrame: 150,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Content(),
    ),
    Layer.overlay(
      blendMode: BlendMode.screen,
      child: Watermark(),
    ),
  ],
)
```

### Audio

Add background music or sound effects:

```dart
AudioTrack(
  source: AudioSource.asset('audio/music.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  fadeInFrames: 30,
  fadeOutFrames: 30,
  volume: 0.8,
)
```

## Rendering

### Using RenderController (Recommended)

```dart
final controller = RenderController();

// In your widget tree
RenderableComposition(
  controller: controller,
  composition: myComposition,
);

// To render
final config = controller.config;
if (config != null) {
  final service = RenderService();
  await service.execute(
    config: config,
    repaintBoundaryKey: controller.boundaryKey,
    onFrameUpdate: controller.setFrame,
    onComplete: (outputPath) {
      print('Video saved to: $outputPath');
    },
  );
}
```

### Checking FFmpeg Availability

```dart
final diagnostics = await FFmpegChecker.check();
if (!diagnostics.isAvailable) {
  print('FFmpeg not found: ${diagnostics.errorMessage}');
  print(diagnostics.installationInstructions);
}
```

### Custom FFmpeg Path

```dart
void main() {
  FluvieConfig.configure(
    ffmpegPath: '/opt/ffmpeg/bin/ffmpeg',
  );
  runApp(MyApp());
}
```

## Platform Support

| Platform | Status | Provider |
|----------|--------|----------|
| Linux | Supported | ProcessFFmpegProvider |
| macOS | Supported | ProcessFFmpegProvider |
| Windows | Supported | ProcessFFmpegProvider |
| Web | Supported | WasmFFmpegProvider |
| Android | Custom | Set via FFmpegProviderRegistry |
| iOS | Custom | Set via FFmpegProviderRegistry |

### Custom Provider (Mobile)

For mobile platforms, implement your own provider using [ffmpeg_kit_flutter](https://pub.dev/packages/ffmpeg_kit_flutter):

```dart
void main() {
  FFmpegProviderRegistry.setProvider(MyFFmpegKitProvider());
  runApp(MyApp());
}
```

## Documentation

- [API Reference](https://simonerich.github.io/fluvie/)
- [Getting Started](doc/getting_started.md)
- [Widget Reference](doc/widgets.md)
- [Platform Setup](doc/platform_setup/overview.md)
- [Migration Guide](doc/migration_guide.md)
- [Examples](example/)

## Troubleshooting

### FFmpeg Not Found

Run the FFmpeg checker to diagnose:

```dart
final diagnostics = await FFmpegChecker.check();
print(diagnostics);
```

### Web: SharedArrayBuffer Not Available

Ensure your server sends the required CORS headers. See [Web Setup](doc/platform_setup/web.md).

### Mobile: No Default Provider

Mobile platforms require a custom provider. See [Mobile Setup](doc/platform_setup/mobile.md).

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Created by [Simon Auer](https://github.com/simonerich)
