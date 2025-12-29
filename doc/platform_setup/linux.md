# Linux Setup

> **Install and configure FFmpeg on Linux**

## Table of Contents

- [Installation](#installation)
- [Bundling FFmpeg](#bundling-ffmpeg-with-your-app)
- [Snap/Flatpak](#snapflatpak-considerations)
- [Troubleshooting](#troubleshooting)

---

## Installation

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install ffmpeg
```

### Fedora

```bash
sudo dnf install ffmpeg
```

### Arch Linux

```bash
sudo pacman -S ffmpeg
```

### Verify Installation

```bash
ffmpeg -version
```

## Bundling FFmpeg with Your App

For distribution, you can bundle FFmpeg with your application:

### Using CMakeLists.txt

Add to `linux/CMakeLists.txt`:

```cmake
# Copy FFmpeg binary to bundle
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
                    GROUP_EXECUTE GROUP_READ)
```

### Configure Fluvie to Use Bundled FFmpeg

```dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fluvie/fluvie.dart';

void main() {
  // Get the directory where the executable is located
  final execDir = path.dirname(Platform.resolvedExecutable);
  final ffmpegPath = path.join(execDir, 'lib', 'ffmpeg');

  if (File(ffmpegPath).existsSync()) {
    FluvieConfig.configure(ffmpegPath: ffmpegPath);
  }

  runApp(MyApp());
}
```

## Snap/Flatpak Considerations

If distributing via Snap or Flatpak, FFmpeg may need to be included in your package or accessed via a plug/portal.

### Snap

Add to `snap/snapcraft.yaml`:

```yaml
parts:
  my-app:
    stage-packages:
      - ffmpeg
```

### Flatpak

Add to your manifest:

```json
{
  "modules": [
    {
      "name": "ffmpeg",
      "buildsystem": "autotools",
      "sources": [
        {
          "type": "archive",
          "url": "https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz"
        }
      ]
    }
  ]
}
```

## Troubleshooting

### FFmpeg Not Found

1. Check if FFmpeg is in PATH:
   ```bash
   which ffmpeg
   ```

2. If installed but not in PATH, configure the path:
   ```dart
   FluvieConfig.configure(ffmpegPath: '/usr/local/bin/ffmpeg');
   ```

### Permission Denied

Ensure the FFmpeg binary has execute permissions:

```bash
chmod +x /path/to/ffmpeg
```

### Missing Codecs

Some distributions ship FFmpeg without proprietary codecs. Install the full version:

```bash
# Ubuntu with restricted codecs
sudo apt install ffmpeg ubuntu-restricted-extras
```

---

## Related

- [Platform Overview](overview.md) - All platforms
- [FFmpeg Setup](../getting-started/ffmpeg-setup.md) - General FFmpeg guide
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Custom integrations
