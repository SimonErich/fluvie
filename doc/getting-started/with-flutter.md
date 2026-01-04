# Getting Started with Fluvie (Manual Flutter Setup)

> **Build videos programmatically with complete control**

This guide walks you through setting up Fluvie in a Flutter project from scratch, understanding the core concepts, and creating your first video.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Create Project](#step-1-create-project)
- [Step 2: Add Fluvie](#step-2-add-fluvie)
- [Step 3: Create Your Video](#step-3-create-your-video)
- [Step 4: Preview with VideoPreview](#step-4-preview-with-videopreview)
- [Step 5: Export Your Video](#step-5-export-your-video)
- [Complete Project Structure](#complete-project-structure)
- [Core Concepts](#core-concepts)

---

## Prerequisites

Before starting, ensure you have:

- **Flutter SDK** 3.16+ installed
- **Dart SDK** 3.2+
- **FFmpeg** installed for video encoding
- A code editor (VS Code, Android Studio, etc.)

### Install FFmpeg

```bash
# macOS
brew install ffmpeg

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg

# Windows
# Download from https://ffmpeg.org and add to PATH
```

Verify installation:
```bash
ffmpeg -version
```

---

## Step 1: Create Project

```bash
# Create a new Flutter project
flutter create my_fluvie_video
cd my_fluvie_video
```

---

## Step 2: Add Fluvie

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^1.0.0
```

Or use the command line:

```bash
flutter pub add fluvie
```

Then fetch dependencies:

```bash
flutter pub get
```

---

## Step 3: Create Your Video

Create `lib/videos/hello_video.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

/// A simple "Hello Fluvie" video with two scenes.
class HelloVideo extends StatelessWidget {
  const HelloVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Video(
      // Video settings
      fps: 30,                    // 30 frames per second
      width: 1080,                // Output width
      height: 1920,               // Output height (9:16 vertical)

      // Transition between scenes
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),

      // Video scenes
      scenes: [
        _buildIntroScene(),
        _buildOutroScene(),
      ],
    );
  }

  /// Scene 1: Intro with animated title
  Scene _buildIntroScene() {
    return Scene(
      durationInFrames: 120, // 4 seconds at 30fps

      // Animated gradient background
      background: Background.gradient(
        colors: {
          0: const Color(0xFF1a1a2e),   // Start color
          120: const Color(0xFF0f3460), // End color
        },
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),

      // Scene fades
      fadeInFrames: 20,
      fadeOutFrames: 15,

      // Content
      children: [
        VCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main title - slides up and fades in
              AnimatedText.slideUpFade(
                'Hello Fluvie!',
                duration: 30,        // Animation takes 30 frames (1 second)
                startFrame: 10,      // Starts at frame 10
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // Subtitle - fades in after title
              AnimatedText.fadeIn(
                'Your first programmatic video',
                duration: 20,
                startFrame: 50,      // Starts after title finishes
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Scene 2: Outro with call to action
  Scene _buildOutroScene() {
    return Scene(
      durationInFrames: 120, // 4 seconds

      background: Background.gradient(
        colors: {
          0: const Color(0xFF0f3460),
          120: const Color(0xFFe94560),
        },
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),

      fadeInFrames: 15,
      fadeOutFrames: 30,

      children: [
        VCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with scale animation
              AnimatedProp(
                animation: PropAnimation.combine([
                  PropAnimation.zoomIn(start: 0.5),
                  PropAnimation.fadeIn(),
                ]),
                duration: 30,
                startFrame: 5,
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.auto_awesome,
                  size: 80,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Closing text
              AnimatedText.scaleFade(
                'Made with Fluvie',
                startFrame: 40,
                duration: 25,
                startScale: 0.8,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

---

## Step 4: Preview with VideoPreview

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'videos/hello_video.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Fluvie Video',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VideoEditorPage(),
    );
  }
}

class VideoEditorPage extends StatefulWidget {
  const VideoEditorPage({super.key});

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  final _controller = VideoPreviewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Video'),
        actions: [
          // Frame counter
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'Frame ${_controller.currentFrame} / ${_controller.totalFrames}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: VideoPreview(
        video: const HelloVideo(),
        controller: _controller,
        showControls: true,
        showExportButton: true,
        onFrameUpdate: (frame, total) {
          // Optional: React to frame changes
        },
        onComplete: () {
          // Optional: Called when video completes (before loop)
        },
      ),
    );
  }
}
```

### Run the Preview

```bash
flutter run
```

You'll see your video playing with:
- **Play/Pause button** - Control playback
- **Scrubber** - Seek to any frame
- **Export button** - Render to MP4

---

## Step 5: Export Your Video

### Option A: Use the Export Button

The `VideoPreview` widget's export button handles everything automatically.

### Option B: Programmatic Export

For more control, use `VideoExporter`:

```dart
import 'package:fluvie/fluvie.dart';

Future<void> exportVideo() async {
  final path = await VideoExporter(const HelloVideo())
    .withQuality(RenderQuality.high)
    .withFileName('hello_fluvie.mp4')
    .withProgress((progress) {
      print('Export progress: ${(progress * 100).toInt()}%');
    })
    .render();

  print('Video saved to: $path');

  // Optionally save to Downloads
  await FileSaver.save(path, suggestedName: 'hello_fluvie.mp4');
}
```

### Option C: With Progress UI

```dart
class ExportButton extends StatefulWidget {
  final Video video;

  const ExportButton({super.key, required this.video});

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  bool _isExporting = false;
  double _progress = 0.0;

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _progress = 0.0;
    });

    try {
      await VideoExporter(widget.video)
        .withProgress((p) => setState(() => _progress = p))
        .renderAndSave();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isExporting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%'),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _export,
      icon: const Icon(Icons.download),
      label: const Text('Export Video'),
    );
  }
}
```

---

## Complete Project Structure

```
my_fluvie_video/
├── lib/
│   ├── main.dart              # App entry point
│   └── videos/
│       └── hello_video.dart   # Your video composition
├── pubspec.yaml
└── ...
```

---

## Core Concepts

### Frame-Based Timing

Everything in Fluvie uses frame numbers, not seconds:

```dart
// At 30 fps:
// 30 frames = 1 second
// 60 frames = 2 seconds
// 90 frames = 3 seconds

Scene(
  durationInFrames: 90,  // 3 seconds at 30fps
  ...
)
```

### Widget Hierarchy

```
Video
└── Scene (can have multiple)
    ├── Background
    └── children (any Flutter widgets)
        ├── VCenter, VColumn, VRow (layout)
        ├── AnimatedText, AnimatedProp (animation)
        └── ParticleEffect, etc. (effects)
```

### Key Widgets

| Widget | Purpose |
|--------|---------|
| `Video` | Root container, defines fps/dimensions |
| `Scene` | Time-bounded section with background |
| `VCenter` | Centers content vertically & horizontally |
| `AnimatedText` | Text with built-in animations |
| `AnimatedProp` | Animates any widget property |
| `VideoPreview` | Handles preview playback |
| `VideoExporter` | Exports to MP4 |

---

## Next Steps

- [Widget Reference](../widgets/README.md) - All available widgets
- [Animations](../animations/README.md) - Animation patterns
- [Templates](../templates/README.md) - Pre-built templates
- [Vibecoding with MCP](with-mcp.md) - AI-assisted development
- [Headless Rendering](headless.md) - Server-side generation

---

## Troubleshooting

### "FFmpeg not found"

Ensure FFmpeg is in your PATH:
```bash
which ffmpeg  # macOS/Linux
where ffmpeg  # Windows
```

### "Video shows nothing"

Make sure you're using `VideoPreview` or wrapping with `FrameProvider`:
```dart
// Wrong - won't animate
Scaffold(body: HelloVideo())

// Correct - animates properly
Scaffold(body: VideoPreview(video: HelloVideo()))
```

### "Animations don't start"

Check your `startFrame` values - they're relative to the scene, not the video:
```dart
AnimatedText.slideUpFade(
  'Hello',
  startFrame: 10,  // Frame 10 of THIS scene
  duration: 30,
)
```
