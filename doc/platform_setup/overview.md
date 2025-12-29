# Platform Setup Overview

> **Configure FFmpeg for your target platform**

Fluvie requires FFmpeg to encode video output. This guide covers how to set up FFmpeg for each supported platform.

## Table of Contents

- [Supported Platforms](#supported-platforms)
- [Quick Start](#quick-start)
- [Checking FFmpeg Availability](#checking-ffmpeg-availability)
- [Custom FFmpeg Path](#custom-ffmpeg-path)
- [Platform-Specific Guides](#platform-specific-guides)

---

## Supported Platforms

| Platform | Provider | Setup Required | Notes |
|----------|----------|----------------|-------|
| Linux | ProcessFFmpegProvider | Install FFmpeg via package manager | Best performance |
| macOS | ProcessFFmpegProvider | Install FFmpeg via Homebrew | Best performance |
| Windows | ProcessFFmpegProvider | Download FFmpeg and add to PATH | Best performance |
| Web | WasmFFmpegProvider | Add CORS headers to server | ~50% slower than native |
| Android | Custom (FFmpegKit) | Add ffmpeg_kit_flutter dependency | +8-35MB app size |
| iOS | Custom (FFmpegKit) | Add ffmpeg_kit_flutter dependency | +8-35MB app size |

---

## Quick Start

### Desktop (Linux, macOS, Windows)

FFmpeg must be installed and available in your system PATH:

```bash
# Linux
sudo apt install ffmpeg

# macOS
brew install ffmpeg

# Windows - Download from ffmpeg.org and add to PATH
```

### Web

No installation needed - Fluvie uses ffmpeg.wasm automatically. However, your server must send these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### Mobile (Android/iOS)

Mobile platforms require a custom FFmpeg provider. We recommend using FFmpegKit:

```dart
// In your app's main.dart
import 'package:fluvie/fluvie.dart';
import 'your_ffmpeg_kit_provider.dart';

void main() {
  FFmpegProviderRegistry.setProvider(FFmpegKitProvider());
  runApp(MyApp());
}
```

## Checking FFmpeg Availability

Use `FFmpegChecker` to verify setup:

```dart
import 'package:fluvie/fluvie.dart';

void checkSetup() async {
  final diagnostics = await FFmpegChecker.check();

  if (diagnostics.isAvailable) {
    print('FFmpeg ready: ${diagnostics.providerName}');
  } else {
    print('FFmpeg not found: ${diagnostics.errorMessage}');
    print(diagnostics.installationInstructions);
  }
}
```

## Custom FFmpeg Path

If FFmpeg is installed in a non-standard location:

```dart
void main() {
  FluvieConfig.configure(
    ffmpegPath: '/opt/ffmpeg/bin/ffmpeg',
    ffprobePath: '/opt/ffmpeg/bin/ffprobe',
  );
  runApp(MyApp());
}
```

## Platform-Specific Guides

| Guide | Platform | Description |
|-------|----------|-------------|
| [Linux Setup](linux.md) | Ubuntu, Fedora, Arch | Package manager installation |
| [macOS Setup](macos.md) | macOS 10.15+ | Homebrew installation, code signing |
| [Windows Setup](windows.md) | Windows 10/11 | Manual or Chocolatey installation |
| [Web Setup](web.md) | Browsers | CORS configuration for ffmpeg.wasm |
| [Mobile Setup](mobile.md) | Android/iOS | FFmpegKit integration |

---

## Related

- [Getting Started](../getting-started/README.md) - First steps with Fluvie
- [FFmpeg Setup](../getting-started/ffmpeg-setup.md) - Detailed FFmpeg guide
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Custom integrations
- [Server Mode](../ONLY_SERVER_MODE.md) - Server-only rendering
