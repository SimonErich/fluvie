# Your First Video

> **Create a complete animated video from scratch**

This guide walks you through building a simple but complete video with animated text, a gradient background, and smooth transitions.

## Table of Contents

- [What We'll Build](#what-well-build)
- [Step 1: Create the Widget](#step-1-create-the-widget)
- [Step 2: Add a Scene](#step-2-add-a-scene)
- [Step 3: Add Animated Text](#step-3-add-animated-text)
- [Step 4: Add a Second Scene](#step-4-add-a-second-scene)
- [Step 5: Preview Your Video](#step-5-preview-your-video)
- [Step 6: Export the Video](#step-6-export-the-video)
- [Complete Code](#complete-code)

---

## What We'll Build

A 6-second video with:
- **Scene 1:** Animated title on a gradient background
- **Scene 2:** Closing message with fade transition

The final result will look something like:

```
[0-3s]  Purple gradient → "Hello, World!" slides up
[3-6s]  Blue gradient → "Made with Fluvie" fades in
```

---

## Step 1: Create the Widget

Start with the basic `Video` widget. This is the root of your composition:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class MyFirstVideo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,           // 30 frames per second
      width: 1920,       // Full HD width
      height: 1080,      // Full HD height
      scenes: [
        // We'll add scenes here
      ],
    );
  }
}
```

**Key points:**
- `fps: 30` means 30 frames per second (standard for most videos)
- `width` and `height` set the output resolution
- `scenes` is a list of `Scene` widgets

---

## Step 2: Add a Scene

Add your first scene with a gradient background:

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90, // 90 frames = 3 seconds at 30fps
      background: Background.gradient(
        colors: {
          0: Color(0xFF6366F1),   // Indigo at start
          90: Color(0xFF8B5CF6),  // Purple at end
        },
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      children: [
        // Content goes here
      ],
    ),
  ],
)
```

**Key points:**
- `length: 90` = 3 seconds at 30fps (90 ÷ 30 = 3)
- `Background.gradient` animates between colors over the scene duration
- The color keys (0, 90) are frame numbers

---

## Step 3: Add Animated Text

Add a title that slides up and fades in:

```dart
Scene(
  durationInFrames: 90,
  background: Background.gradient(
    colors: {
      0: Color(0xFF6366F1),
      90: Color(0xFF8B5CF6),
    },
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  children: [
    // Center the content
    VCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main title - slides up and fades in
          AnimatedText.slideUpFade(
            'Hello, World!',
            startFrame: 10,     // Start at frame 10
            duration: 30,       // Animate over 30 frames (1 second)
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          // Subtitle - appears after the title
          AnimatedText.fadeIn(
            'Your first Fluvie video',
            startFrame: 40,     // Start after title finishes
            duration: 20,
            style: TextStyle(
              fontSize: 32,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),
  ],
)
```

**Key points:**
- `VCenter` centers content vertically and horizontally
- `AnimatedText.slideUpFade` combines slide and fade animations
- `startFrame` controls when the animation begins
- `duration` controls how long the animation takes

---

## Step 4: Add a Second Scene

Add a closing scene with a transition:

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  defaultTransition: SceneTransition.crossFade(durationInFrames: 15),
  scenes: [
    // Scene 1 (from Step 3)
    Scene(
      durationInFrames: 90,
      // ... (previous scene content)
    ),

    // Scene 2 - Outro
    Scene(
      durationInFrames: 90,
      background: Background.gradient(
        colors: {
          0: Color(0xFF0EA5E9),   // Sky blue
          90: Color(0xFF0284C7),  // Darker blue
        },
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      children: [
        VCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sparkle effect
              AnimatedProp(
                startFrame: 5,
                duration: 30,
                animation: PropAnimation.combine([
                  PropAnimation.zoomIn(start: 0.5),
                  PropAnimation.fadeIn(),
                ]),
                child: Icon(
                  Icons.auto_awesome,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              // Closing text
              AnimatedText.scaleFade(
                'Made with Fluvie',
                startFrame: 30,
                duration: 25,
                startScale: 0.8,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ],
)
```

**Key points:**
- `defaultTransition` applies between all scenes
- `SceneTransition.crossFade` fades between scenes
- `AnimatedProp` allows combining multiple animations
- `PropAnimation.combine` merges scale and fade effects

---

## Step 5: Preview Your Video

### Using VideoPreview (Recommended)

The easiest way to preview your video is with the `VideoPreview` widget, which handles all the animation and playback boilerplate for you:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'my_first_video.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: VideoPreview(
        video: MyFirstVideo(),
        showControls: true,      // Play/pause, scrubber
        showExportButton: true,  // Export to MP4
      ),
    ),
  ));
}
```

### Run the Preview

```bash
flutter run
```

Your video will play automatically with:
- **Play/Pause** button
- **Scrubber** to seek to any frame
- **Export button** to render to MP4

### Advanced: External Controller

For more control over playback, use a `VideoPreviewController`:

```dart
class VideoPage extends StatefulWidget {
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _controller = VideoPreviewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: VideoPreview(
            video: MyFirstVideo(),
            controller: _controller,
            showControls: true,
          ),
        ),
        // Custom controls
        ElevatedButton(
          onPressed: () => _controller.seekTo(0),
          child: Text('Reset'),
        ),
      ],
    );
  }
}
```

---

## Step 6: Export the Video

### Option A: Use VideoPreview's Export Button

If you set `showExportButton: true` on `VideoPreview`, clicking the download button will automatically render and save your video.

### Option B: Use VideoExporter (Programmatic)

For more control over export, use `VideoExporter`:

```dart
ElevatedButton(
  child: Text('Export Video'),
  onPressed: () async {
    final path = await VideoExporter(MyFirstVideo())
      .withQuality(RenderQuality.high)
      .withFileName('my_first_video.mp4')
      .withProgress((progress) {
        print('Progress: ${(progress * 100).toInt()}%');
      })
      .render();

    print('Saved to: $path');

    // Or render and save to Downloads in one step:
    // await VideoExporter(MyFirstVideo()).renderAndSave();
  },
)
```

### Option C: Export via Test (Automated)

For CI/CD or automated rendering, use a test file:

```dart
// test/render_first_video_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:your_app/my_first_video.dart';

void main() {
  testWidgets('Render first video', (tester) async {
    final path = await VideoExporter(MyFirstVideo())
      .withQuality(RenderQuality.high)
      .withProgress((p) => print('${(p * 100).toInt()}%'))
      .render();

    print('Video saved to: $path');
  });
}
```

Run with:
```bash
flutter test test/render_first_video_test.dart
```

---

### Legacy: Manual Export (Not Recommended)

If you need fine-grained control, you can use `RenderService` directly:

```dart
ElevatedButton(
  child: Text('Export Video'),
  onPressed: () async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Rendering...'),
          ],
        ),
      ),
    );

    // Render the video
    final renderService = RenderService();
    final outputPath = await renderService.execute(
      context: context,
      outputPath: 'output/my_first_video.mp4',
      onFrameUpdate: (frame) async {
        await Future.delayed(Duration(milliseconds: 16));
      },
    );

    // Close dialog
    Navigator.pop(context);

    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to: $outputPath')),
    );
  },
)
```

### Option B: Export via Test (Recommended)

Create a test file for automated rendering:

```dart
// test/render_first_video_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:your_app/my_first_video.dart';

void main() {
  testWidgets('Render first video', (tester) async {
    // Build the video
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyFirstVideo(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Get context and render
    final context = tester.element(find.byType(Video));
    final renderService = RenderService();

    final outputPath = await renderService.execute(
      context: context,
      outputPath: 'output/my_first_video.mp4',
      onFrameUpdate: (frame) async {
        await tester.pump();
      },
      onProgress: (progress) {
        print('Rendering: ${(progress * 100).toStringAsFixed(0)}%');
      },
    );

    print('✅ Video saved to: $outputPath');
  });
}
```

Run the test:

```bash
flutter test test/render_first_video_test.dart
```

---

## Complete Code

Here's the complete `MyFirstVideo` widget:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class MyFirstVideo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1920,
      height: 1080,
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
      scenes: [
        // Scene 1: Hello World
        Scene(
          durationInFrames: 90,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF6366F1),
              90: const Color(0xFF8B5CF6),
            },
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          children: [
            VCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedText.slideUpFade(
                    'Hello, World!',
                    startFrame: 10,
                    duration: 30,
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedText.fadeIn(
                    'Your first Fluvie video',
                    startFrame: 40,
                    duration: 20,
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Scene 2: Made with Fluvie
        Scene(
          durationInFrames: 90,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF0EA5E9),
              90: const Color(0xFF0284C7),
            },
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          children: [
            VCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedProp(
                    startFrame: 5,
                    duration: 30,
                    animation: PropAnimation.combine([
                      PropAnimation.zoomIn(start: 0.5),
                      PropAnimation.fadeIn(),
                    ]),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedText.scaleFade(
                    'Made with Fluvie',
                    startFrame: 30,
                    duration: 25,
                    startScale: 0.8,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## What's Next?

Congratulations! You've created your first Fluvie video. Here's where to go next:

1. **[Simple Animation Tutorial](../tutorials/simple-animation.md)** - Add images and music
2. **[Advanced Composition Tutorial](../tutorials/advanced-composition.md)** - Multiple scenes, video clips, effects
3. **[Widget Reference](../widgets/README.md)** - Explore all available widgets
4. **[Examples](../../example/)** - See production-ready examples

---

## Tips for Getting Started

1. **Start simple** - Get the basics working before adding complexity
2. **Preview often** - Use hot reload to see changes instantly
3. **Think in frames** - At 30fps: 30 frames = 1 second
4. **Use `VCenter`** - It centers content and handles timing
5. **Experiment** - Try different animations and see what looks good
