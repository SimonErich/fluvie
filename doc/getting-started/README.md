# Getting Started

> **Go from zero to your first video in minutes**

This section guides you through setting up Fluvie and creating your first animated video.

## Table of Contents

- [Installation](installation.md) - Add Fluvie to your project
- [FFmpeg Setup](ffmpeg-setup.md) - Configure video encoding
- [First Video](first-video.md) - Build a complete animated video

---

## Quick Start

### 1. Add the Package

```yaml
# pubspec.yaml
dependencies:
  fluvie: ^1.0.0
```

### 2. Install FFmpeg

```bash
# macOS
brew install ffmpeg

# Linux
sudo apt install ffmpeg

# Windows
# Download from ffmpeg.org and add to PATH
```

### 3. Create Your First Video

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90, // 3 seconds
      background: Background.solid(Colors.indigo),
      children: [
        VCenter(
          child: AnimatedText.slideUpFade(
            'Hello, Fluvie!',
            style: TextStyle(
              fontSize: 72,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ],
)
```

---

## What's Next?

After completing the getting started guides:

1. **[Tutorials](../tutorials/README.md)** - Build complete video projects
2. **[Widget Reference](../widgets/README.md)** - Explore all available widgets
3. **[Examples](../../example/)** - See working code examples

---

## Prerequisites

Before starting, you should have:

- **Flutter SDK** installed (3.16+)
- **Dart SDK** (3.2+)
- **Basic Flutter knowledge** (widgets, build methods)
- **A code editor** (VS Code, Android Studio, etc.)

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux | Full Support | Best for CI/CD |
| macOS | Full Support | Development & CI |
| Windows | Full Support | FFmpeg in PATH required |
| Web | Full Support | Uses ffmpeg.wasm |
| iOS | Custom Provider | Requires FFmpegKit |
| Android | Custom Provider | Requires FFmpegKit |

See [Platform Setup](../platform_setup/overview.md) for detailed instructions.

---

## Need Help?

- [GitHub Issues](https://github.com/simonerich/fluvie/issues) - Report bugs
- [Examples](../../example/) - Working code to reference
- [Contributing](../contributing/support.md) - Get support
