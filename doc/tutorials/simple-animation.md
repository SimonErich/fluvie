# Tutorial: Simple Animation

> **Build a video with image, animated text, and background music**

In this tutorial, you'll create a 30-second video with a gradient background, an animated image, text overlays, and background music. This is perfect for social media intros, announcements, or personal videos.

## Table of Contents

- [What We're Building](#what-were-building)
- [Setup](#setup)
- [Step 1: Basic Composition](#step-1-basic-composition)
- [Step 2: Add a Background](#step-2-add-a-background)
- [Step 3: Add an Image](#step-3-add-an-image)
- [Step 4: Add Animated Text](#step-4-add-animated-text)
- [Step 5: Add Background Music](#step-5-add-background-music)
- [Step 6: Preview and Export](#step-6-preview-and-export)
- [Complete Code](#complete-code)
- [Variations](#variations)

---

## What We're Building

A polished 30-second video featuring:

| Time | Content |
|------|---------|
| 0-3s | Gradient fades in |
| 1-5s | Image appears with Ken Burns effect |
| 3-6s | Title slides up |
| 5-8s | Subtitle fades in |
| 8-28s | Content holds |
| 28-30s | Everything fades out |

Music plays throughout with fade in at the start and fade out at the end.

---

## Setup

### Create Project Structure

```
lib/
├── main.dart
└── videos/
    └── simple_animation.dart

assets/
├── images/
│   └── hero.jpg        # Your main image (1920x1080 recommended)
└── audio/
    └── background.mp3  # Background music (30+ seconds)
```

### Update pubspec.yaml

```yaml
flutter:
  assets:
    - assets/images/
    - assets/audio/
```

### Sample Assets

If you don't have assets ready:
- Use any landscape photo for `hero.jpg`
- Use any music file for `background.mp3`
- Or find free assets at [Pexels](https://pexels.com), [Pixabay](https://pixabay.com)

---

## Step 1: Basic Composition

Create the video widget with basic settings:

```dart
// lib/videos/simple_animation.dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class SimpleAnimationVideo extends StatelessWidget {
  const SimpleAnimationVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1920,
      height: 1080,
      scenes: [
        Scene(
          durationInFrames: 900, // 30 seconds at 30fps
          children: [
            // Content will go here
          ],
        ),
      ],
    );
  }
}
```

**Understanding the timing:**
- `fps: 30` = 30 frames per second
- `length: 900` = 900 frames ÷ 30fps = 30 seconds

---

## Step 2: Add a Background

Add an animated gradient background:

```dart
Scene(
  durationInFrames: 900,
  background: Background.gradient(
    colors: {
      0: const Color(0xFF1a1a2e),     // Dark blue at start
      450: const Color(0xFF16213e),   // Navy at middle
      900: const Color(0xFF0f3460),   // Deep blue at end
    },
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  fadeInFrames: 30,   // Fade in over 1 second
  fadeOutFrames: 60,  // Fade out over 2 seconds
  children: [
    // Content will go here
  ],
)
```

**What's happening:**
- `Background.gradient` creates an animated gradient
- Color keys (0, 450, 900) are frame numbers
- The gradient smoothly transitions between colors
- `fadeInFrames` and `fadeOutFrames` add smooth transitions

---

## Step 3: Add an Image

Add a hero image with Ken Burns effect (slow zoom and pan):

```dart
Scene(
  durationInFrames: 900,
  background: Background.gradient(/* ... */),
  fadeInFrames: 30,
  fadeOutFrames: 60,
  children: [
    // Hero image with Ken Burns effect
    Positioned.fill(
      child: KenBurnsImage(
        imagePath: 'assets/images/hero.jpg',
        startFrame: 30,      // Start after fade-in
        durationInFrames: 840, // Most of the video
        zoomStart: 1.0,      // Start at normal size
        zoomEnd: 1.15,       // End 15% zoomed in
        panStart: Offset.zero,
        panEnd: const Offset(0.05, 0.02), // Slight pan right and down
        fadeInFrames: 45,    // 1.5 second fade in
        fadeOutFrames: 30,   // 1 second fade out
      ),
    ),
  ],
)
```

**Alternative: Simple image without Ken Burns**

If you prefer a static image:

```dart
// Simple positioned image
VPositioned(
  startFrame: 30,
  fadeInFrames: 45,
  fadeOutFrames: 30,
  endFrame: 870,
  child: Positioned.fill(
    child: Image.asset(
      'assets/images/hero.jpg',
      fit: BoxFit.cover,
    ),
  ),
),
```

---

## Step 4: Add Animated Text

Add a title and subtitle with staggered animations:

```dart
Scene(
  durationInFrames: 900,
  background: Background.gradient(/* ... */),
  fadeInFrames: 30,
  fadeOutFrames: 60,
  children: [
    // Hero image (from Step 3)
    Positioned.fill(
      child: KenBurnsImage(/* ... */),
    ),

    // Overlay gradient for text readability
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.5, 1.0],
          ),
        ),
      ),
    ),

    // Text content positioned at bottom
    VPositioned(
      bottom: 120,
      left: 80,
      right: 80,
      startFrame: 90,       // Start at 3 seconds
      fadeInFrames: 30,
      fadeOutFrames: 60,
      endFrame: 840,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main title - slides up
          AnimatedText.slideUpFade(
            'Your Amazing Title',
            startFrame: 0,  // Relative to VPositioned startFrame
            duration: 30,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle - fades in after title
          AnimatedText.fadeIn(
            'A subtitle that explains more about this video',
            startFrame: 20,
            duration: 25,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    ),
  ],
)
```

**What's happening:**
- The overlay gradient makes text readable over the image
- `VPositioned` positions text and handles timing
- `startFrame` in `AnimatedText` is relative to parent's `startFrame`
- Text appears staggered: title first, then subtitle

---

## Step 5: Add Background Music

Wrap everything with an audio track:

```dart
@override
Widget build(BuildContext context) {
  return Video(
    fps: 30,
    width: 1920,
    height: 1080,
    // Simple way: use built-in music properties
    backgroundMusicAsset: 'assets/audio/background.mp3',
    musicVolume: 0.7,
    musicFadeInFrames: 60,   // 2 second fade in
    musicFadeOutFrames: 90,  // 3 second fade out
    scenes: [
      Scene(/* ... */),
    ],
  );
}
```

**Alternative: More control with AudioTrack**

For more control over audio timing:

```dart
return Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 900,
      background: Background.gradient(/* ... */),
      children: [
        // Wrap content with AudioTrack
        BackgroundAudio(
          source: AudioSource.asset('assets/audio/background.mp3'),
          volume: 0.7,
          fadeInFrames: 60,
          fadeOutFrames: 90,
          child: Stack(
            children: [
              // All your content here
              Positioned.fill(child: KenBurnsImage(/* ... */)),
              // ... text overlay, etc.
            ],
          ),
        ),
      ],
    ),
  ],
);
```

---

## Step 6: Preview and Export

### Preview the Video

Add to your main.dart:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'videos/simple_animation.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: SimpleAnimationVideo(),
        ),
      ),
    ),
  ));
}
```

Run:

```bash
flutter run
```

### Export the Video

Create a test file:

```dart
// test/render_simple_animation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:your_app/videos/simple_animation.dart';

void main() {
  testWidgets('Render simple animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SimpleAnimationVideo()),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Video));
    final renderService = RenderService();

    final outputPath = await renderService.execute(
      context: context,
      outputPath: 'output/simple_animation.mp4',
      onFrameUpdate: (frame) async => await tester.pump(),
      onProgress: (progress) {
        print('Rendering: ${(progress * 100).toStringAsFixed(0)}%');
      },
    );

    print('✅ Video saved to: $outputPath');
  });
}
```

Run:

```bash
flutter test test/render_simple_animation_test.dart --timeout=none
```

---

## Complete Code

Here's the complete `simple_animation.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class SimpleAnimationVideo extends StatelessWidget {
  const SimpleAnimationVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1920,
      height: 1080,
      backgroundMusicAsset: 'assets/audio/background.mp3',
      musicVolume: 0.7,
      musicFadeInFrames: 60,
      musicFadeOutFrames: 90,
      scenes: [
        Scene(
          durationInFrames: 900, // 30 seconds
          background: Background.gradient(
            colors: {
              0: const Color(0xFF1a1a2e),
              450: const Color(0xFF16213e),
              900: const Color(0xFF0f3460),
            },
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          fadeInFrames: 30,
          fadeOutFrames: 60,
          children: [
            // Hero image with Ken Burns effect
            Positioned.fill(
              child: KenBurnsImage(
                imagePath: 'assets/images/hero.jpg',
                startFrame: 30,
                durationInFrames: 840,
                zoomStart: 1.0,
                zoomEnd: 1.15,
                panStart: Offset.zero,
                panEnd: const Offset(0.05, 0.02),
                fadeInFrames: 45,
                fadeOutFrames: 30,
              ),
            ),

            // Overlay gradient for text
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Sparkle particles
            Positioned.fill(
              child: ParticleEffect.sparkles(
                count: 20,
                color: Colors.white.withOpacity(0.3),
              ),
            ),

            // Text content
            VPositioned(
              bottom: 120,
              left: 80,
              right: 80,
              startFrame: 90,
              fadeInFrames: 30,
              fadeOutFrames: 60,
              endFrame: 840,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedText.slideUpFade(
                    'Your Amazing Title',
                    startFrame: 0,
                    duration: 30,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedText.fadeIn(
                    'A subtitle that explains more about this video',
                    startFrame: 20,
                    duration: 25,
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Subtle vignette
            const Positioned.fill(
              child: EffectOverlay.vignette(intensity: 0.3),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Variations

### Vertical Format (9:16)

For TikTok/Instagram Stories:

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920, // Vertical!
  // ... rest same
)
```

### Square Format (1:1)

For Instagram feed:

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1080, // Square!
  // ... rest same
)
```

### Different Animation Styles

Try different text animations:

```dart
// Type out the text
TypewriterText(
  'Your Amazing Title',
  startFrame: 0,
  charsPerSecond: 15,
  style: TextStyle(/* ... */),
)

// Scale up with fade
AnimatedText.scaleFade(
  'Your Amazing Title',
  startScale: 0.8,
  // ...
)

// Glitch effect entrance
AnimatedProp(
  animation: const EntryAnimation.glitchSlide(
    direction: EntrySlideDirection.fromBottom,
  ),
  // ...
)
```

### Add More Visual Interest

```dart
// Add confetti at the end
VPositioned(
  startFrame: 800,
  child: ParticleEffect.confetti(count: 50),
),

// Add a progress bar
VPositioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      return Container(
        height: 4,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    },
  ),
),
```

---

## Next Steps

Ready for more? Continue to:

1. **[Advanced Composition Tutorial](advanced-composition.md)** - Multi-scene videos
2. **[Effects Reference](../effects/README.md)** - More visual effects
3. **[Templates](../templates/README.md)** - Pre-built video templates
