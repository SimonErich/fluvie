# Windows Setup

> **Install and configure FFmpeg on Windows**

## Table of Contents

- [Installation](#installation)
- [Package Managers](#using-chocolatey)
- [Bundling FFmpeg](#bundling-ffmpeg-with-your-app)
- [MSIX Packaging](#msix-packaging)
- [Troubleshooting](#troubleshooting)

---

## Installation

### Download FFmpeg

1. Go to [ffmpeg.org/download.html](https://ffmpeg.org/download.html)
2. Under "Windows", click on "Windows builds from gyan.dev"
3. Download the "ffmpeg-release-essentials.zip" (or full build for more codecs)
4. Extract to a folder (e.g., `C:\ffmpeg`)

### Add to PATH

1. Open System Properties (Win+Pause or search "Environment Variables")
2. Click "Environment Variables"
3. Under "System variables", find "Path" and click "Edit"
4. Click "New" and add `C:\ffmpeg\bin`
5. Click OK to save

### Verify Installation

Open a new Command Prompt and run:

```cmd
ffmpeg -version
```

## Using Chocolatey

```cmd
choco install ffmpeg
```

## Using Scoop

```cmd
scoop install ffmpeg
```

## Using winget

```cmd
winget install FFmpeg
```

## Bundling FFmpeg with Your App

### Download and Extract

1. Download the static FFmpeg build
2. Extract `ffmpeg.exe` and `ffprobe.exe`
3. Place them in your project's `windows/` directory

### Modify CMakeLists.txt

Add to `windows/CMakeLists.txt`:

```cmake
# Install FFmpeg binaries
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg.exe"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/ffprobe.exe"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}")
```

### Configure Fluvie

```dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fluvie/fluvie.dart';

void main() {
  final execDir = path.dirname(Platform.resolvedExecutable);
  final ffmpegPath = path.join(execDir, 'data', 'ffmpeg.exe');

  if (File(ffmpegPath).existsSync()) {
    FluvieConfig.configure(ffmpegPath: ffmpegPath);
  }

  runApp(MyApp());
}
```

## MSIX Packaging

When creating an MSIX package:

### Include FFmpeg in Package

Add to your `pubspec.yaml`:

```yaml
msix_config:
  assets_directory_path: windows/assets
```

Place FFmpeg in `windows/assets/`.

### Configure at Runtime

```dart
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For MSIX, assets are in a specific location
  final appDir = await getApplicationSupportDirectory();
  final ffmpegPath = path.join(appDir.path, 'ffmpeg.exe');

  if (File(ffmpegPath).existsSync()) {
    FluvieConfig.configure(ffmpegPath: ffmpegPath);
  }

  runApp(MyApp());
}
```

## Troubleshooting

### 'ffmpeg' is not recognized

FFmpeg is not in PATH. Either:

1. Add FFmpeg to PATH (see installation steps)
2. Or configure the full path:
   ```dart
   FluvieConfig.configure(ffmpegPath: r'C:\ffmpeg\bin\ffmpeg.exe');
   ```

### Windows Defender SmartScreen

When running an unsigned app with bundled FFmpeg:

1. Click "More info"
2. Click "Run anyway"

For distribution, consider code signing your application.

### Antivirus False Positives

Some antivirus software flags FFmpeg. You may need to:

1. Add an exception for your app's directory
2. Use a well-known FFmpeg distribution (gyan.dev, BtbN)

### Long Path Issues

If you encounter path length issues:

1. Enable long paths in Windows:
   ```cmd
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
   ```
2. Restart your computer

---

## Related

- [Platform Overview](overview.md) - All platforms
- [FFmpeg Setup](../getting-started/ffmpeg-setup.md) - General FFmpeg guide
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Custom integrations
