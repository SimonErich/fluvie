# macOS Setup

> **Install and configure FFmpeg on macOS**

## Table of Contents

- [Installation](#installation)
- [Bundling FFmpeg](#bundling-ffmpeg-with-your-app)
- [Code Signing](#code-signing)
- [Notarization](#notarization)
- [Troubleshooting](#troubleshooting)

---

## Installation

### Using Homebrew (Recommended)

```bash
brew install ffmpeg
```

### Using MacPorts

```bash
sudo port install ffmpeg
```

### Verify Installation

```bash
ffmpeg -version
```

## Bundling FFmpeg with Your App

For distribution via the Mac App Store or notarized apps, you'll want to bundle FFmpeg.

### Download Static Build

1. Download a static FFmpeg build from [evermeet.cx](https://evermeet.cx/ffmpeg/)
2. Place the binary in your project

### Add to Xcode Project

1. In Xcode, right-click on Runner → Add Files to "Runner"
2. Select the FFmpeg binary
3. Ensure "Copy items if needed" is checked
4. Add to the Runner target

### Configure Build Phase

Add a "Copy Files" build phase:

1. Select your target → Build Phases
2. Add a "Copy Files" phase
3. Destination: Executables
4. Add the FFmpeg binary

### Configure Fluvie

```dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fluvie/fluvie.dart';

void main() {
  final execDir = path.dirname(Platform.resolvedExecutable);
  final ffmpegPath = path.join(execDir, 'ffmpeg');

  if (File(ffmpegPath).existsSync()) {
    FluvieConfig.configure(ffmpegPath: ffmpegPath);
  }

  runApp(MyApp());
}
```

## Code Signing

When distributing your app, the bundled FFmpeg binary must be signed.

### Sign the Binary

```bash
codesign --force --sign "Developer ID Application: Your Name" \
  --options runtime \
  path/to/ffmpeg
```

### Entitlements

Create `ffmpeg.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

Sign with entitlements:

```bash
codesign --force --sign "Developer ID Application: Your Name" \
  --options runtime \
  --entitlements ffmpeg.entitlements \
  path/to/ffmpeg
```

## Notarization

For distribution outside the App Store:

```bash
# Create a zip for notarization
ditto -c -k --keepParent YourApp.app YourApp.zip

# Submit for notarization
xcrun notarytool submit YourApp.zip \
  --apple-id your@email.com \
  --team-id YOURTEAMID \
  --password app-specific-password \
  --wait

# Staple the ticket
xcrun stapler staple YourApp.app
```

## Troubleshooting

### "ffmpeg" cannot be opened because the developer cannot be verified

This happens when FFmpeg isn't properly signed. Either:

1. Sign the binary as shown above
2. Or for development, allow it in System Preferences → Security & Privacy

### Library Not Loaded

If FFmpeg reports missing libraries:

```bash
# Check dependencies
otool -L /path/to/ffmpeg
```

Use a statically linked FFmpeg build to avoid dependency issues.

### Sandboxed App Restrictions

If your app is sandboxed, FFmpeg may have limited file access. Ensure you:

1. Request necessary entitlements
2. Use app-accessible directories (Documents, temp)
3. Or disable sandbox for development

---

## Related

- [Platform Overview](overview.md) - All platforms
- [FFmpeg Setup](../getting-started/ffmpeg-setup.md) - General FFmpeg guide
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Custom integrations
