# FFmpeg Setup

> **Configure video encoding for your platform**

Fluvie uses FFmpeg to encode video output. This guide covers installation and configuration for all supported platforms.

## Table of Contents

- [Quick Install](#quick-install)
- [Verifying Installation](#verifying-installation)
- [Platform-Specific Guides](#platform-specific-guides)
- [Custom FFmpeg Path](#custom-ffmpeg-path)
- [Troubleshooting](#troubleshooting)

---

## Quick Install

### macOS

Using Homebrew:

```bash
brew install ffmpeg
```

### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install ffmpeg
```

### Linux (Fedora)

```bash
sudo dnf install ffmpeg
```

### Linux (Arch)

```bash
sudo pacman -S ffmpeg
```

### Windows

1. Download from [ffmpeg.org](https://ffmpeg.org/download.html)
2. Extract to a folder (e.g., `C:\ffmpeg`)
3. Add to PATH:
   - Search "Environment Variables" in Windows
   - Edit "Path" under User or System variables
   - Add `C:\ffmpeg\bin`
4. Restart your terminal

### Web

No installation needed! Fluvie uses **ffmpeg.wasm** automatically.

However, your server must send these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### Mobile (iOS/Android)

Mobile platforms require a custom FFmpeg provider. See [Mobile Setup](../platform_setup/mobile.md).

---

## Verifying Installation

### Command Line Check

```bash
ffmpeg -version
```

You should see version information like:

```
ffmpeg version 6.0 Copyright (c) 2000-2023 the FFmpeg developers
built with Apple clang version 14.0.3
...
```

### From Your Flutter App

Use `FFmpegChecker` to verify from Dart:

```dart
import 'package:fluvie/fluvie.dart';

Future<void> checkFFmpeg() async {
  final diagnostics = await FFmpegChecker.check();

  if (diagnostics.isAvailable) {
    print('✅ FFmpeg is available');
    print('   Provider: ${diagnostics.providerName}');
    print('   Version: ${diagnostics.version}');
  } else {
    print('❌ FFmpeg not found');
    print('   Error: ${diagnostics.errorMessage}');
    print('');
    print('Installation instructions:');
    print(diagnostics.installationInstructions);
  }
}
```

### Quick Test Widget

Add a diagnostic button to your app:

```dart
ElevatedButton(
  child: Text('Check FFmpeg'),
  onPressed: () async {
    final diagnostics = await FFmpegChecker.check();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(diagnostics.isAvailable ? 'FFmpeg Ready' : 'FFmpeg Missing'),
        content: Text(
          diagnostics.isAvailable
              ? 'Provider: ${diagnostics.providerName}'
              : diagnostics.installationInstructions,
        ),
      ),
    );
  },
)
```

---

## Platform-Specific Guides

For detailed setup instructions:

| Platform | Guide |
|----------|-------|
| Linux | [Linux Setup](../platform_setup/linux.md) |
| macOS | [macOS Setup](../platform_setup/macos.md) |
| Windows | [Windows Setup](../platform_setup/windows.md) |
| Web | [Web Setup](../platform_setup/web.md) |
| Mobile | [Mobile Setup](../platform_setup/mobile.md) |

---

## Custom FFmpeg Path

If FFmpeg is installed in a non-standard location, configure the path:

### Global Configuration

```dart
import 'package:fluvie/fluvie.dart';

void main() {
  FluvieConfig.configure(
    ffmpegPath: '/opt/local/bin/ffmpeg',
    ffprobePath: '/opt/local/bin/ffprobe',
  );

  runApp(MyApp());
}
```

### Common Custom Paths

| Platform | Location |
|----------|----------|
| macOS (Homebrew ARM) | `/opt/homebrew/bin/ffmpeg` |
| macOS (Homebrew Intel) | `/usr/local/bin/ffmpeg` |
| Linux (snap) | `/snap/bin/ffmpeg` |
| Windows | `C:\ffmpeg\bin\ffmpeg.exe` |

### Finding Your FFmpeg Path

```bash
# macOS/Linux
which ffmpeg

# Windows
where ffmpeg
```

---

## FFmpeg Providers

Fluvie uses a provider system to abstract FFmpeg integration:

### ProcessFFmpegProvider (Desktop)

Default for Linux, macOS, Windows. Runs FFmpeg as a child process.

```dart
// Automatically selected on desktop
FFmpegProviderRegistry.provider; // ProcessFFmpegProvider
```

### WasmFFmpegProvider (Web)

Default for web. Uses ffmpeg.wasm in the browser.

```dart
// Automatically selected on web
FFmpegProviderRegistry.provider; // WasmFFmpegProvider
```

### Custom Provider (Mobile)

For iOS/Android, you must provide a custom implementation:

```dart
// In your app's main.dart
import 'package:fluvie/fluvie.dart';
import 'your_ffmpeg_kit_provider.dart';

void main() {
  FFmpegProviderRegistry.setProvider(FFmpegKitProvider());
  runApp(MyApp());
}
```

See [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) for implementation details.

---

## Recommended FFmpeg Version

Fluvie works with FFmpeg 4.0 and later. Recommended:

| Version | Status |
|---------|--------|
| 4.x | Supported |
| 5.x | Supported |
| 6.x | Recommended |
| 7.x | Supported |

### Required Features

Fluvie requires these FFmpeg features (included in standard builds):

- libx264 (H.264 encoding)
- libx265 (H.265 encoding, optional)
- aac (audio encoding)
- rawvideo (frame input)
- filter_complex (audio/video filtering)

Check available encoders:

```bash
ffmpeg -encoders | grep -E "264|265|aac"
```

---

## Troubleshooting

### "FFmpeg not found"

**Symptoms:** `FFmpegChecker.check()` returns `isAvailable: false`

**Solutions:**

1. Verify installation:
   ```bash
   ffmpeg -version
   ```

2. Check PATH:
   ```bash
   echo $PATH  # macOS/Linux
   echo %PATH% # Windows
   ```

3. Restart your terminal/IDE after installation

4. Set explicit path:
   ```dart
   FluvieConfig.configure(ffmpegPath: '/path/to/ffmpeg');
   ```

### "Permission denied"

**Symptoms:** FFmpeg fails to write output files

**Solutions:**

1. Check output directory exists
2. Check write permissions
3. Try a different output path:
   ```dart
   final outputPath = '${Directory.systemTemp.path}/output.mp4';
   ```

### "Codec not found"

**Symptoms:** Error about missing libx264 or other codec

**Solutions:**

1. Install a full FFmpeg build (not minimal)
2. macOS: `brew install ffmpeg` (includes all codecs)
3. Linux: `sudo apt install ffmpeg` (includes common codecs)

### Web: "SharedArrayBuffer is not defined"

**Symptoms:** ffmpeg.wasm fails to load

**Solutions:**

Add required headers to your web server:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

For local development with `flutter run`:

```bash
flutter run -d chrome --web-browser-flag "--enable-features=SharedArrayBuffer"
```

### Slow Encoding

**Symptoms:** Video export takes very long

**Solutions:**

1. Use raw RGBA format (faster than PNG):
   ```dart
   encoding: EncodingConfig(
     frameFormat: FrameFormat.rawRgba,
   )
   ```

2. Lower quality for testing:
   ```dart
   encoding: EncodingConfig(
     quality: RenderQuality.low,
   )
   ```

3. Reduce resolution during development:
   ```dart
   Video(
     width: 960,  // Half resolution
     height: 540,
   )
   ```

---

## Next Steps

1. **[First Video](first-video.md)** - Create your first video
2. **[Encoding Settings](../advanced/encoding-settings.md)** - Fine-tune output

---

## Related Documentation

- [Platform Setup Overview](../platform_setup/overview.md)
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md)
- [Encoding Settings](../advanced/encoding-settings.md)
