# Fluvie

Fluvie is a Flutter package for programmatic video generation. It allows you to create videos using Flutter widgets and export them using FFmpeg.

## Features

- **Declarative Video Composition:** Use Flutter widgets to define your video scenes.
- **Dual-Engine Architecture:** Leverages Flutter for rendering and FFmpeg for encoding.
- **Frame-Perfect Rendering:** Ensures synchronization between animation frames and video frames.
- **Rich Text & Effects:** Supports text, overlays, and basic effects.

## Getting Started

See the [Getting Started Guide](docs/getting_started.md) for detailed instructions.

### Installation

Add `fluvie` to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.0.1
```

### Usage

```dart
import 'package:fluvie/fluvie.dart';

// Define your composition
final composition = VideoComposition(
  fps: 30,
  durationInFrames: 150,
  child: MyVideoContent(),
);

// Render
final service = RenderService();
await service.execute(
  config: composition.toConfig(),
  repaintBoundaryKey: myKey,
  onFrameUpdate: (frame) { ... },
);
```

## Documentation

- [Widgets Reference](docs/widgets.md)
- [Architecture Concept](docs/concept.md)

## Contributing

Contributions are welcome! Please read our contributing guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
