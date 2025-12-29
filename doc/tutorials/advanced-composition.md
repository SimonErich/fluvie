# Tutorial: Advanced Composition

> **Build a multi-scene video with transitions, embedded video, effects, and synced audio**

In this tutorial, you'll create a professional 1-minute video with multiple scenes, smooth transitions, embedded video clips, particle effects, and precisely synced audio.

## Table of Contents

- [What We're Building](#what-were-building)
- [Setup](#setup)
- [Step 1: Scene Structure](#step-1-scene-structure)
- [Step 2: Intro Scene](#step-2-intro-scene)
- [Step 3: Content Scene with Embedded Video](#step-3-content-scene-with-embedded-video)
- [Step 4: Statistics Scene with Stagger](#step-4-statistics-scene-with-stagger)
- [Step 5: Outro with Particles](#step-5-outro-with-particles)
- [Step 6: Add Sound Effects](#step-6-add-sound-effects)
- [Step 7: Final Polish](#step-7-final-polish)
- [Complete Code](#complete-code)
- [Advanced Techniques](#advanced-techniques)

---

## What We're Building

A polished 1-minute video with 4 scenes:

| Scene | Duration | Content |
|-------|----------|---------|
| 1. Intro | 8s | Logo zoom, title reveal with glitch effect |
| 2. Content | 20s | Embedded video clip with text overlay |
| 3. Statistics | 20s | Staggered stat cards with count-up animation |
| 4. Outro | 12s | Thank you message with confetti celebration |

Features:
- Scene transitions (crossfade, slide)
- Embedded video with synced audio
- Particle effects (sparkles, confetti)
- Staggered list animations
- Sound effects at key moments
- Background music throughout

---

## Setup

### Project Structure

```
lib/
├── main.dart
└── videos/
    └── advanced_composition.dart

assets/
├── images/
│   └── logo.png
├── videos/
│   └── highlight.mp4       # A 15-20 second video clip
├── audio/
│   ├── background.mp3      # Background music (60+ seconds)
│   ├── whoosh.mp3          # Transition sound effect
│   └── success.mp3         # Celebration sound effect
```

### Update pubspec.yaml

```yaml
flutter:
  assets:
    - assets/images/
    - assets/videos/
    - assets/audio/
```

---

## Step 1: Scene Structure

Start with the overall composition structure:

```dart
// lib/videos/advanced_composition.dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class AdvancedCompositionVideo extends StatelessWidget {
  const AdvancedCompositionVideo({super.key});

  // Constants for timing (at 30fps)
  static const int fps = 30;
  static const int introLength = 8 * fps;      // 240 frames
  static const int contentLength = 20 * fps;   // 600 frames
  static const int statsLength = 20 * fps;     // 600 frames
  static const int outroLength = 12 * fps;     // 360 frames

  // Total: 1800 frames = 60 seconds

  @override
  Widget build(BuildContext context) {
    return Video(
      fps: fps,
      width: 1920,
      height: 1080,
      encoding: const EncodingConfig(
        quality: RenderQuality.high,
        frameFormat: FrameFormat.rawRgba,
      ),
      backgroundMusicAsset: 'assets/audio/background.mp3',
      musicVolume: 0.6,
      musicFadeInFrames: 60,
      musicFadeOutFrames: 120,
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 20),
      scenes: [
        _buildIntroScene(),
        _buildContentScene(),
        _buildStatsScene(),
        _buildOutroScene(),
      ],
    );
  }

  Scene _buildIntroScene() {
    return Scene(
      durationInFrames: introLength,
      children: [/* Step 2 */],
    );
  }

  Scene _buildContentScene() {
    return Scene(
      durationInFrames: contentLength,
      children: [/* Step 3 */],
    );
  }

  Scene _buildStatsScene() {
    return Scene(
      durationInFrames: statsLength,
      children: [/* Step 4 */],
    );
  }

  Scene _buildOutroScene() {
    return Scene(
      durationInFrames: outroLength,
      children: [/* Step 5 */],
    );
  }
}
```

---

## Step 2: Intro Scene

Create a dynamic intro with logo zoom and glitch text reveal:

```dart
Scene _buildIntroScene() {
  return Scene(
    durationInFrames: introLength,
    background: Background.gradient(
      colors: {
        0: const Color(0xFF0a0a0a),
        introLength: const Color(0xFF1a1a2e),
      },
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    fadeInFrames: 20,
    children: [
      // Subtle grid overlay
      const Positioned.fill(
        child: EffectOverlay.grid(
          color: Color(0xFF6366F1),
          intensity: 0.03,
        ),
      ),

      // Sparkles
      Positioned.fill(
        child: ParticleEffect.sparkles(
          count: 30,
          color: const Color(0xFF6366F1).withOpacity(0.5),
        ),
      ),

      // Logo zooms in
      VCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedProp(
              startFrame: 10,
              duration: 50,
              animation: PropAnimation.combine([
                PropAnimation.zoomIn(start: 0.3),
                PropAnimation.fadeIn(),
              ]),
              curve: Easing.easeOutBack,
              child: Image.asset(
                'assets/images/logo.png',
                width: 200,
                height: 200,
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6366F1),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Title with glitch entrance
            AnimatedProp(
              startFrame: 60,
              duration: 40,
              animation: const EntryAnimation.glitchSlide(
                direction: EntrySlideDirection.fromBottom,
                distance: 100,
                rgbOffset: 8,
              ),
              child: const Text(
                'YEAR IN REVIEW',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle fades in
            AnimatedText.fadeIn(
              '2024 Highlights',
              startFrame: 100,
              duration: 30,
              style: TextStyle(
                fontSize: 28,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),

      // Scanlines for tech feel
      const Positioned.fill(
        child: EffectOverlay.scanlines(intensity: 0.02),
      ),
    ],
  );
}
```

---

## Step 3: Content Scene with Embedded Video

Add a scene featuring an embedded video clip:

```dart
Scene _buildContentScene() {
  const videoStartFrame = 30;
  const videoDuration = contentLength - 60; // Leave room for transitions

  return Scene(
    durationInFrames: contentLength,
    transitionIn: const SceneTransition.slideRight(durationInFrames: 25),
    background: Background.solid(const Color(0xFF0f3460)),
    children: [
      // Section title at top
      VPositioned(
        top: 60,
        left: 0,
        right: 0,
        startFrame: 10,
        fadeInFrames: 20,
        child: AnimatedText.slideUpFade(
          'TOP MOMENT',
          startFrame: 0,
          duration: 25,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w300,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),

      // Embedded video with frame
      VPositioned(
        top: 150,
        left: 120,
        startFrame: videoStartFrame,
        fadeInFrames: 30,
        fadeOutFrames: 30,
        endFrame: contentLength - 30,
        child: AnimatedProp(
          animation: PropAnimation.slideUp(distance: 50),
          duration: 35,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: EmbeddedVideo(
                assetPath: 'assets/videos/highlight.mp4',
                width: 1200,
                height: 675, // 16:9 aspect ratio
                startFrame: videoStartFrame,
                durationInFrames: videoDuration,
                includeAudio: true,
                audioVolume: 0.8,
                audioFadeInFrames: 15,
                audioFadeOutFrames: 30,
              ),
            ),
          ),
        ),
      ),

      // Video caption
      VPositioned(
        bottom: 80,
        left: 120,
        right: 120,
        startFrame: videoStartFrame + 60,
        fadeInFrames: 20,
        fadeOutFrames: 30,
        endFrame: contentLength - 30,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFe94560),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FEATURED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Our most memorable moment of the year',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
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
  );
}
```

---

## Step 4: Statistics Scene with Stagger

Create an animated statistics display with staggered card animations:

```dart
Scene _buildStatsScene() {
  return Scene(
    durationInFrames: statsLength,
    background: Background.gradient(
      colors: {
        0: const Color(0xFF667eea),
        statsLength: const Color(0xFF764ba2),
      },
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    children: [
      // Section title
      VPositioned(
        top: 80,
        left: 0,
        right: 0,
        startFrame: 10,
        fadeInFrames: 25,
        child: AnimatedText.slideUpFade(
          'BY THE NUMBERS',
          startFrame: 0,
          duration: 30,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 8,
          ),
          textAlign: TextAlign.center,
        ),
      ),

      // Stats grid with stagger
      VPositioned(
        top: 220,
        left: 100,
        right: 100,
        startFrame: 50,
        fadeOutFrames: 40,
        endFrame: statsLength - 40,
        child: Column(
          children: [
            // Row 1
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    value: 365,
                    label: 'DAYS',
                    sublabel: 'of creating',
                    color: const Color(0xFFff6b6b),
                    startFrame: 50,
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: _buildStatCard(
                    value: 1842,
                    label: 'HOURS',
                    sublabel: 'of work',
                    color: const Color(0xFF4ecdc4),
                    startFrame: 70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Row 2
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    value: 52,
                    label: 'PROJECTS',
                    sublabel: 'completed',
                    color: const Color(0xFFffe66d),
                    startFrame: 90,
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: _buildStatCard(
                    value: 12,
                    label: 'AWARDS',
                    sublabel: 'won',
                    color: const Color(0xFFa29bfe),
                    startFrame: 110,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // Subtle sparkles
      Positioned.fill(
        child: ParticleEffect.sparkles(
          count: 25,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    ],
  );
}

Widget _buildStatCard({
  required int value,
  required String label,
  required String sublabel,
  required Color color,
  required int startFrame,
}) {
  return AnimatedProp(
    startFrame: startFrame,
    duration: 40,
    animation: PropAnimation.combine([
      PropAnimation.zoomIn(start: 0.7),
      PropAnimation.fadeIn(),
    ]),
    curve: Easing.easeOutBack,
    child: StatCard(
      value: value,
      label: label,
      sublabel: sublabel,
      color: color,
      startFrame: startFrame + 20, // Count starts after card appears
      countDuration: 40,
      size: const Size(double.infinity, 200),
      borderRadius: 20,
      padding: const EdgeInsets.all(24),
    ),
  );
}
```

---

## Step 5: Outro with Particles

Create a celebration outro with confetti:

```dart
Scene _buildOutroScene() {
  return Scene(
    durationInFrames: outroLength,
    background: Background.gradient(
      colors: {
        0: const Color(0xFFf12711),
        outroLength ~/ 2: const Color(0xFFf5af19),
        outroLength: const Color(0xFFf12711),
      },
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    fadeOutFrames: 60,
    children: [
      // Confetti celebration
      Positioned.fill(
        child: ParticleEffect.confetti(
          count: 60,
          colors: [
            Colors.white,
            Colors.amber,
            Colors.pink,
            const Color(0xFF6366F1),
            Colors.cyan,
          ],
        ),
      ),

      // Trophy icon
      VCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedProp(
              startFrame: 10,
              duration: 35,
              animation: PropAnimation.combine([
                PropAnimation.zoomIn(start: 0),
                PropAnimation.fadeIn(),
              ]),
              curve: Easing.elastic,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFffd700), Color(0xFFffa500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFffd700).withOpacity(0.4),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 50),

            // "What a year" text
            AnimatedText.fadeIn(
              'WHAT A YEAR',
              startFrame: 40,
              duration: 25,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.95),
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedText.scaleFade(
              "IT'S BEEN!",
              startFrame: 60,
              duration: 30,
              startScale: 0.8,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 60),

            // Thank you message
            AnimatedText.fadeIn(
              'Thank you for an amazing journey',
              startFrame: 100,
              duration: 25,
              style: TextStyle(
                fontSize: 28,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),

      // Film grain for warmth
      const Positioned.fill(
        child: EffectOverlay.grain(intensity: 0.04),
      ),
    ],
  );
}
```

---

## Step 6: Add Sound Effects

Add sound effects at key moments using AudioTrack:

```dart
// In _buildIntroScene(), add:
AudioTrack(
  source: AudioSource.asset('assets/audio/whoosh.mp3'),
  startFrame: 60,  // When title appears
  durationInFrames: 30,
  volume: 0.5,
  child: const SizedBox.shrink(), // Invisible, just for audio
),

// In _buildOutroScene(), add:
AudioTrack(
  source: AudioSource.asset('assets/audio/success.mp3'),
  startFrame: 10,  // When trophy appears
  durationInFrames: 60,
  volume: 0.6,
  fadeInFrames: 5,
  child: const SizedBox.shrink(),
),
```

**Alternative: Using sync points**

For precise audio-visual sync:

```dart
// Create a sync anchor at a key moment
SyncAnchor(
  id: 'beat_drop',
  frame: 60,
  child: AnimatedProp(
    // Animation synced to this point
  ),
),

// Sync audio to the anchor
AudioTrack.syncStart(
  source: AudioSource.asset('assets/audio/whoosh.mp3'),
  syncAnchorId: 'beat_drop',
  offsetFrames: -5, // Start 5 frames before anchor
  durationInFrames: 30,
  child: const SizedBox.shrink(),
),
```

---

## Step 7: Final Polish

### Add Quality Settings

```dart
return Video(
  // ...
  encoding: const EncodingConfig(
    quality: RenderQuality.high, // Uses slow preset, CRF 18
    frameFormat: FrameFormat.rawRgba, // Fastest capture
    debugFrameOutputPath: null, // Don't save debug frames in production
  ),
  // ...
);
```

### Add Scene-Specific Transitions

```dart
Scene _buildContentScene() {
  return Scene(
    durationInFrames: contentLength,
    transitionIn: const SceneTransition.slideRight(durationInFrames: 25),
    transitionOut: const SceneTransition.crossFade(durationInFrames: 20),
    // ...
  );
}
```

### Test at Different Resolutions

```dart
// For quick testing
Video(
  width: 960,   // Half resolution
  height: 540,
  // ...
)

// For final export
Video(
  width: 1920,
  height: 1080,
  // ...
)

// For 4K
Video(
  width: 3840,
  height: 2160,
  // ...
)
```

---

## Complete Code

The complete code is extensive. See the reference implementation:

📁 `example/lib/gallery/examples/example_year_review.dart`

Key patterns from the complete example:

1. **Constants for timing** - Define durations as constants
2. **Helper methods for repeated patterns** - Like `_buildStatCard()`
3. **Relative frame numbers** - Child animations relative to parent
4. **Layer ordering** - Background → Content → Effects → Overlays

---

## Advanced Techniques

### Dynamic Content

Generate content from data:

```dart
final stats = [
  {'value': 365, 'label': 'Days', 'color': Colors.red},
  {'value': 1842, 'label': 'Hours', 'color': Colors.teal},
  // ...
];

children: [
  for (var i = 0; i < stats.length; i++)
    _buildStatCard(
      value: stats[i]['value'] as int,
      label: stats[i]['label'] as String,
      color: stats[i]['color'] as Color,
      startFrame: 50 + (i * 20), // Stagger by 20 frames
    ),
]
```

### Responsive Layouts

Adapt to different aspect ratios:

```dart
@override
Widget build(BuildContext context) {
  final isVertical = Video.aspectRatio < 1;

  return Scene(
    children: [
      if (isVertical)
        _buildVerticalLayout()
      else
        _buildHorizontalLayout(),
    ],
  );
}
```

### Custom Easing

Create custom animation curves:

```dart
final customCurve = Cubic(0.68, -0.55, 0.265, 1.55); // Overshoot

AnimatedProp(
  curve: customCurve,
  // ...
)
```

### Looping Elements

Create infinitely looping animations:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final loopProgress = (frame % 60) / 60; // 2-second loop at 30fps
    final pulse = 1.0 + 0.1 * sin(loopProgress * 2 * pi);

    return Transform.scale(
      scale: pulse,
      child: MyWidget(),
    );
  },
)
```

---

## Next Steps

You've now mastered advanced Fluvie compositions! Explore:

1. **[Templates](../templates/README.md)** - Pre-built professional templates
2. **[Effects Reference](../effects/README.md)** - All available effects
3. **[Extending Fluvie](../extending/README.md)** - Create custom components
4. **[Production Examples](../../example/)** - Real-world implementations
