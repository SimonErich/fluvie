# Fluvie AI Reference Documentation

> **Complete reference for AI assistants and IDEs to generate Fluvie video composition code**

Fluvie is a Flutter library for creating animated videos programmatically. Use `import 'package:fluvie/declarative.dart';` to access the full API.

---

## Quick Reference

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1080,
  height: 1920,  // 9:16 vertical
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
  scenes: [
    Scene(
      durationInFrames: 120,  // frames (4 seconds at 30fps)
      background: Background.gradient(colors: {0: Colors.purple, 120: Colors.blue}),
      children: [
        VCenter(child: AnimatedText.slideUpFade('Hello!', duration: 30)),
      ],
    ),
  ],
)
```

### Key Concepts

- **Frame-based timing**: All durations in frames, not seconds (`fps: 30` means 30 frames = 1 second)
- **Declarative API**: Use `Video` and `Scene` widgets for composition
- **Dual-engine model**: Flutter for rendering, FFmpeg for encoding
- **Progress-based animations**: Animations use 0.0 to 1.0 progress values

### Common Aspect Ratios

| Format | Dimensions | Use Case |
|--------|------------|----------|
| Vertical (9:16) | 1080x1920 | TikTok, Stories, Reels |
| Square (1:1) | 1080x1080 | Instagram Feed |
| Landscape (16:9) | 1920x1080 | YouTube, Desktop |
| Cinematic (21:9) | 2560x1080 | Film style |

---

## Core Widgets

### Video

Root widget for video composition. Manages scenes, transitions, and audio.

```dart
Video(
  fps: 30,                    // Required: frames per second
  width: 1080,                // Required: output width
  height: 1920,               // Required: output height
  scenes: [...],              // Required: list of Scene widgets

  // Optional
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
  backgroundMusicAsset: 'assets/music.mp3',
  musicVolume: 0.7,           // 0.0-1.0
  musicFadeInFrames: 60,
  musicFadeOutFrames: 90,
  encoding: const EncodingConfig(
    quality: RenderQuality.high,
    frameFormat: FrameFormat.png,
  ),
)
```

### Scene

Time-bounded section of video with background and content.

```dart
Scene(
  durationInFrames: 120,                // Required: duration in frames

  // Optional
  background: Background.gradient(
    colors: {0: Color(0xFF1a1a2e), 120: Color(0xFF0f3460)},
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  fadeInFrames: 20,
  fadeOutFrames: 15,
  transitionIn: const SceneTransition.slideUp(durationInFrames: 20),
  transitionOut: const SceneTransition.crossFade(durationInFrames: 15),
  children: [
    // Content widgets
  ],
)
```

### VideoComposition

Low-level composition root for direct frame control.

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      // frame: current frame number (int)
      // progress: 0.0-1.0 across entire video
      return MyContent();
    },
  ),
)
```

### TimeConsumer

Provides current frame for custom animations. Rebuilds every frame.

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final opacity = interpolate(frame, [0, 30], [0.0, 1.0]);
    return Opacity(opacity: opacity, child: Text('Fading in'));
  },
)
```

---

## Layout Widgets

All layout widgets support timing properties: `startFrame`, `endFrame`, `fadeInFrames`, `fadeOutFrames`, `fadeInCurve`, `fadeOutCurve`.

### VCenter

Centers content with optional timing.

```dart
VCenter(
  startFrame: 30,
  fadeInFrames: 15,
  child: Text('Centered'),
)
```

### VPositioned

Absolute positioning with timing and fade support.

```dart
VPositioned(
  top: 100,
  left: 50,
  right: 50,
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  child: Text('Positioned'),
)
```

### VColumn / VRow

Column/Row with stagger animation support.

```dart
VColumn(
  spacing: 20,
  stagger: StaggerConfig.slideUp(delay: 10, duration: 30),
  children: [
    Text('Item 1'),  // Starts at frame 0
    Text('Item 2'),  // Starts at frame 10
    Text('Item 3'),  // Starts at frame 20
  ],
)
```

### VStack

Video-aware Stack widget.

```dart
VStack(
  startFrame: 0,
  endFrame: 120,
  children: [
    BackgroundWidget(),
    ContentWidget(),
  ],
)
```

### VPadding / VSizedBox

Padding and sizing with timing.

```dart
VPadding(
  padding: EdgeInsets.all(20),
  startFrame: 30,
  child: Content(),
)

VSizedBox(
  width: 200,
  height: 100,
  startFrame: 30,
  child: Content(),
)
```

### LayerStack / Layer

Z-indexed layer composition with visibility timing.

```dart
LayerStack(
  children: [
    Layer.background(child: Background()),
    Layer(
      startFrame: 30,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      zIndex: 1,
      child: Content(),
    ),
    Layer.overlay(child: Watermark()),
  ],
)
```

---

## Animation System

### AnimatedProp

Primary animation widget for property animations.

```dart
AnimatedProp(
  animation: PropAnimation.slideUpFade(),
  duration: 30,
  startFrame: 60,
  curve: Curves.easeOutCubic,
  child: Text('Animated'),
)

// Factory constructors
AnimatedProp.fadeIn(duration: 30, child: widget)
AnimatedProp.slideUp(duration: 30, child: widget)
AnimatedProp.zoomIn(duration: 30, child: widget)
AnimatedProp.slideUpFade(duration: 30, child: widget)
```

### PropAnimation

Animation definitions for transforms.

```dart
// Basic animations
PropAnimation.translate(start: Offset(0, 50), end: Offset.zero)
PropAnimation.scale(start: 0.5, end: 1.0)
PropAnimation.rotate(start: 0.0, end: 3.14)  // radians
PropAnimation.fade(start: 0.0, end: 1.0)

// Convenience constructors
PropAnimation.slideUp(distance: 50)
PropAnimation.slideDown(distance: 50)
PropAnimation.slideLeft(distance: 50)
PropAnimation.slideRight(distance: 50)
PropAnimation.zoomIn(start: 0.5)
PropAnimation.zoomOut(end: 0.5)
PropAnimation.fadeIn()
PropAnimation.fadeOut()
PropAnimation.slideUpFade(distance: 50)

// Combined animations
PropAnimation.combine([
  PropAnimation.slideUp(distance: 50),
  PropAnimation.fadeIn(),
  PropAnimation.zoomIn(start: 0.8),
])

// Continuous animations
PropAnimation.float(amplitude: Offset(0, 10), frequency: 0.5)
PropAnimation.pulse(min: 0.9, max: 1.1, frequency: 0.5)
```

### StaggerConfig

Sequential animation for lists of children.

```dart
StaggerConfig(
  delay: 10,          // Frames between each child start
  duration: 30,       // Animation duration per child
  curve: Curves.easeOut,
  fadeIn: true,
  slideIn: true,
  slideOffset: Offset(0, 40),
  scaleIn: false,
  scaleStart: 0.8,
)

// Factory constructors
StaggerConfig.fade(delay: 10, duration: 30)
StaggerConfig.slideUp(delay: 10, duration: 30, distance: 40)
StaggerConfig.slideDown(delay: 10, duration: 30)
StaggerConfig.slideLeft(delay: 10, duration: 30)
StaggerConfig.slideRight(delay: 10, duration: 30)
StaggerConfig.scale(delay: 10, duration: 30, start: 0.8)
StaggerConfig.slideUpScale(delay: 10, duration: 30)
```

### Entry Animations

Dramatic entry effects.

```dart
EntryAnimation.elasticPop()    // Spring-like pop with overshoot
EntryAnimation.strobeReveal()  // Flickering reveal
EntryAnimation.glitchSlide()   // RGB echo glitch effect
EntryAnimation.maskedWipe()    // Shape-based reveal
```

### interpolate()

Keyframe-based value interpolation.

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // Animate value across keyframes
    final opacity = interpolate(
      frame,
      [0, 30, 60, 90],    // Input frames
      [0.0, 1.0, 1.0, 0.0], // Output values
      curve: Curves.easeInOut,
    );
    return Opacity(opacity: opacity, child: widget);
  },
)
```

### Easing Curves

```dart
// Standard
Curves.linear, Curves.easeIn, Curves.easeOut, Curves.easeInOut

// Recommended for entries
Curves.easeOutCubic     // Fast start, gentle landing
Curves.easeOutQuart

// Recommended for exits
Curves.easeInCubic      // Gentle start, fast exit
Curves.easeInQuart

// Emphasis/attention
Curves.easeOutBack      // Overshoot at end
Curves.elasticOut       // Springy

// Custom via Easing class
Easing.easeOutCubic
Easing.easeInOutCubic
Easing.easeOutBack
Easing.elastic
Easing.bounce
```

---

## Text Widgets

### AnimatedText

Text with built-in animations.

```dart
AnimatedText.fadeIn(
  'Hello World',
  startFrame: 0,
  duration: 30,
  style: TextStyle(fontSize: 48, color: Colors.white),
)

AnimatedText.slideUpFade(
  'Animated Text',
  startFrame: 30,
  duration: 25,
  distance: 30,
  style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
)

AnimatedText.scaleFade(
  'Big Entry',
  startFrame: 0,
  duration: 30,
  startScale: 0.5,
  style: TextStyle(fontSize: 120),
)
```

### TypewriterText

Character-by-character reveal.

```dart
TypewriterText(
  'Typing effect...',
  startFrame: 0,
  charsPerSecond: 24,
  style: TextStyle(fontSize: 32),
)
```

### CounterText

Animated number counting.

```dart
CounterText(
  endValue: 1234,
  startFrame: 30,
  duration: 60,
  style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
)
```

### FadeText

Simple text with opacity support.

```dart
FadeText(
  'Simple Text',
  style: TextStyle(fontSize: 24, color: Colors.white),
)
```

---

## Media Widgets

### EmbeddedVideo

Video-in-video with frame synchronization.

```dart
EmbeddedVideo(
  assetPath: 'assets/highlight.mp4',
  width: 900,
  height: 500,
  startFrame: 40,
  durationInFrames: 200,
  trimStart: Duration(seconds: 2),  // Skip first 2 seconds
  borderRadius: BorderRadius.circular(20),
  includeAudio: true,
  audioVolume: 1.0,
  audioFadeInFrames: 15,
  audioFadeOutFrames: 15,
  fit: BoxFit.cover,
)
```

### KenBurnsImage

Slow zoom and pan effect for images.

```dart
KenBurnsImage.zoomIn(
  assetPath: 'assets/photo.jpg',
  width: 800,
  height: 600,
  zoomAmount: 0.2,
  focus: Alignment.center,
)

KenBurnsImage.pan(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
  scale: 1.1,
)

KenBurnsImage.zoomAndPan(
  assetPath: 'assets/photo.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
)
```

---

## Helper Widgets

### StatCard

Animated statistic display with counting animation.

```dart
StatCard(
  value: 1234,
  label: 'PHOTOS',
  sublabel: 'This Year',
  color: Colors.blue,
  startFrame: 30,
  countDuration: 60,
)

StatCard.percentage(
  value: 95,
  label: 'COMPLETED',
  color: Colors.green,
  startFrame: 30,
)

StatCard.currency(
  value: 5000,
  label: 'EARNED',
  symbol: '\$',
  color: Colors.orange,
  startFrame: 30,
)
```

### PolaroidFrame

Photo with instant-camera style frame.

```dart
PolaroidFrame(
  size: Size(300, 350),
  rotation: -0.05,  // Slight tilt
  caption: 'Summer 2024',
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
)

PolaroidFrame.tilted(
  tiltDegrees: -5,
  caption: 'Beach Day',
  child: Image.asset('beach.jpg'),
)
```

### FloatingElement

Oscillating animation for ambient motion.

```dart
FloatingElement(
  position: Offset(100, 200),
  floatAmplitude: Offset(0, 12),
  floatFrequency: 0.04,
  floatPhase: 0.0,
  child: Image.asset('cloud.png'),
)
```

### PhotoCard

Modern photo card with shadow and Ken Burns effect.

```dart
PhotoCard.withKenBurns(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  zoomAmount: 0.15,
  focus: Alignment.center,
)
```

---

## Effects & Backgrounds

### Background

Scene background types.

```dart
// Solid color
Background.solid(Colors.black)

// Animated gradient (colors keyed by frame)
Background.gradient(
  colors: {
    0: Color(0xFF1a1a2e),
    60: Color(0xFF16213e),
    120: Color(0xFF0f3460),
  },
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)

// Image background
Background.image('assets/bg.jpg')

// Noise/grain texture
Background.noise(intensity: 0.1)

// VHS retro effect
Background.vhs()
```

### ParticleEffect

Animated particle systems.

```dart
ParticleEffect.sparkles(
  count: 25,
  color: Colors.yellow,
)

ParticleEffect.confetti(
  count: 40,
  colors: [Colors.red, Colors.blue, Colors.yellow],
)

ParticleEffect.snow(count: 50)
ParticleEffect.bubbles(count: 30)
```

### EffectOverlay

Post-processing visual effects.

```dart
EffectOverlay.scanlines(intensity: 0.02)
EffectOverlay.grain(intensity: 0.06)
EffectOverlay.vignette(intensity: 0.4)
EffectOverlay.grid(color: Color(0xFF00ffcc), intensity: 0.05)
EffectOverlay.crt()  // CRT monitor effect
```

### SceneTransition

Transitions between scenes.

```dart
SceneTransition.none()
SceneTransition.crossFade(durationInFrames: 15)
SceneTransition.slideLeft(durationInFrames: 20)
SceneTransition.slideRight(durationInFrames: 20)
SceneTransition.slideUp(durationInFrames: 20)
SceneTransition.slideDown(durationInFrames: 20)
SceneTransition.scale(durationInFrames: 20)
SceneTransition.wipe(durationInFrames: 20, direction: WipeDirection.left)
SceneTransition.zoomWarp(durationInFrames: 30, maxZoom: 3.0)
SceneTransition.colorBleed(durationInFrames: 20)
```

---

## Templates

30 production-ready templates across 6 categories. Each template accepts specific data types.

### Template Categories

| Category | Templates | Data Type |
|----------|-----------|-----------|
| Intro | TheNeonGate, DigitalMirror, TheMixtape, VortexTitle, NoiseID | `IntroData` |
| Ranking | StackClimb, SlotMachine, TheSpotlight, PerspectiveLadder, FloatingPolaroids | `RankingData` |
| DataViz | OrbitalMetrics, TheGrowthTree, LiquidMinutes, FrequencyGlow, BinaryRain | `MetricsData` |
| Collage | TheGridShuffle, SplitPersonality, MosaicReveal, BentoRecap, TriptychScroll | `CollageData` |
| Thematic | LofiWindow, GlitchReality, RetroPostcard, Kaleidoscope, MinimalistBeat | `ThematicData` |
| Conclusion | ParticleFarewell, TheSignature, TheSummaryPoster, TheInfinityLoop, WrappedReceipt | `SummaryData` |

### Template Data Types

```dart
IntroData(
  title: 'Your 2024',
  subtitle: 'Wrapped',
  year: 2024,
  username: 'optional_user',
)

RankingData(
  title: 'Top Artists',
  items: [
    RankingItem(rank: 1, title: 'Artist One', subtitle: '500 plays', imageUrl: 'url'),
    RankingItem(rank: 2, title: 'Artist Two', subtitle: '420 plays'),
  ],
)

MetricsData(
  title: 'Your Stats',
  metrics: [
    Metric(label: 'Hours', value: 1234),
    Metric(label: 'Songs', value: 5678),
  ],
)

CollageData(
  images: ['url1', 'url2', 'url3'],
  title: 'Your Moments',
)

ThematicData(
  mood: 'chill',
  primaryColor: Colors.purple,
)

SummaryData(
  message: 'Until next time!',
  year: 2024,
  stats: {'songs': 1000, 'artists': 50},
)
```

### Using Templates

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [
    TheNeonGate(
      data: IntroData(title: 'Your 2024', subtitle: 'Wrapped'),
      theme: TemplateTheme(
        primaryColor: Colors.purple,
        backgroundColor: Colors.black,
      ),
    ).toScene(),

    StackClimb(
      data: RankingData(
        title: 'Top Artists',
        items: [
          RankingItem(rank: 1, title: 'Artist One'),
          RankingItem(rank: 2, title: 'Artist Two'),
        ],
      ),
    ).toScene(),

    ParticleFarewell(
      data: SummaryData(message: 'See you next year!'),
    ).toScene(),
  ],
)
```

---

## Audio Support

### AudioTrack

Precise audio timing within scenes.

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/effect.mp3'),
  startFrame: 60,
  durationInFrames: 90,
  volume: 0.8,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  trimStartFrame: 0,
  loop: false,
  child: const SizedBox.shrink(),
)
```

### AudioSource

Audio file references.

```dart
AudioSource.asset('assets/audio/music.mp3')
AudioSource.file('/path/to/audio.mp3')
AudioSource.url('https://example.com/audio.mp3')
```

### BackgroundAudio

Full-video background music.

```dart
BackgroundAudio(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 0.5,
)
```

---

## Complete Example: Year in Review

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class YearReviewVideo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1080,
      height: 1920,
      backgroundMusicAsset: 'assets/music.mp3',
      musicVolume: 0.7,
      musicFadeInFrames: 60,
      musicFadeOutFrames: 90,
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
      encoding: const EncodingConfig(quality: RenderQuality.high),
      scenes: [
        _buildIntroScene(),
        _buildStatsScene(),
        _buildMemoriesScene(),
        _buildOutroScene(),
      ],
    );
  }

  Scene _buildIntroScene() {
    return Scene(
      durationInFrames: 120,
      background: Background.gradient(
        colors: {0: Color(0xFF1a1a2e), 120: Color(0xFF0f3460)},
      ),
      fadeInFrames: 20,
      children: [
        ParticleEffect.sparkles(count: 25),
        VCenter(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText.scaleFade(
                '2024',
                duration: 30,
                startScale: 0.5,
                style: TextStyle(fontSize: 200, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              SizedBox(height: 40),
              AnimatedText.slideUpFade(
                'YOUR YEAR IN REVIEW',
                startFrame: 30,
                duration: 25,
                style: TextStyle(fontSize: 48, color: Colors.white70, letterSpacing: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Scene _buildStatsScene() {
    return Scene(
      durationInFrames: 180,
      background: Background.gradient(
        colors: {0: Color(0xFF2c003e), 180: Color(0xFF512b58)},
      ),
      children: [
        VPositioned(
          top: 200,
          left: 0,
          right: 0,
          child: AnimatedText.slideUpFade(
            'BY THE NUMBERS',
            duration: 25,
            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        VPositioned(
          top: 400,
          left: 60,
          right: 60,
          child: Row(
            children: [
              Expanded(child: StatCard(value: 365, label: 'DAYS', color: Colors.red, startFrame: 30)),
              SizedBox(width: 40),
              Expanded(child: StatCard(value: 1842, label: 'HOURS', color: Colors.teal, startFrame: 50)),
            ],
          ),
        ),
      ],
    );
  }

  Scene _buildMemoriesScene() {
    return Scene(
      durationInFrames: 180,
      background: Background.gradient(
        colors: {0: Color(0xFFff9a9e), 180: Color(0xFFfcb69f)},
      ),
      children: [
        VPositioned(
          top: 150,
          left: 0,
          right: 0,
          child: AnimatedText.slideUpFade(
            'YOUR MEMORIES',
            duration: 25,
            style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Color(0xFF2d3436)),
            textAlign: TextAlign.center,
          ),
        ),
        FloatingElement(
          position: Offset(100, 400),
          floatAmplitude: Offset(0, 10),
          child: PolaroidFrame(
            rotation: -0.08,
            caption: 'Summer vibes',
            child: Image.asset('assets/photo1.jpg', width: 300, height: 260, fit: BoxFit.cover),
          ),
        ),
        FloatingElement(
          position: Offset(550, 600),
          floatAmplitude: Offset(0, 10),
          floatPhase: 45,
          child: PolaroidFrame(
            rotation: 0.06,
            caption: 'Best moments',
            child: Image.asset('assets/photo2.jpg', width: 300, height: 260, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Scene _buildOutroScene() {
    return Scene(
      durationInFrames: 150,
      background: Background.gradient(
        colors: {0: Color(0xFF1a1a2e), 150: Color(0xFFe94560)},
      ),
      children: [
        ParticleEffect.sparkles(count: 40, color: Color(0xFFe94560)),
        VCenter(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText.fadeIn(
                'SEE YOU IN',
                startFrame: 10,
                duration: 25,
                style: TextStyle(fontSize: 48, color: Colors.white70, letterSpacing: 10),
              ),
              SizedBox(height: 20),
              AnimatedText.scaleFade(
                '2025',
                startFrame: 30,
                duration: 35,
                startScale: 0.5,
                style: TextStyle(fontSize: 160, fontWeight: FontWeight.w900, color: Color(0xFFe94560)),
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

## Best Practices

### Animation Timing

```dart
// Text/small elements: 15-30 frames (0.5-1 second)
AnimatedProp(duration: 20, ...)

// Large elements/containers: 30-45 frames (1-1.5 seconds)
AnimatedProp(duration: 40, ...)

// Dramatic reveals: 45-60 frames (1.5-2 seconds)
AnimatedProp(duration: 50, ...)
```

### Stagger Delays

```dart
// Fast stagger: quick succession
StaggerConfig(delay: 5, duration: 20)

// Medium stagger: comfortable pace
StaggerConfig(delay: 10, duration: 25)

// Slow stagger: dramatic reveals
StaggerConfig(delay: 20, duration: 40)
```

### Curve Selection

```dart
// Elements entering (fast start, gentle landing)
curve: Curves.easeOutCubic

// Elements exiting (gentle start, fast exit)
curve: Curves.easeInCubic

// Emphasis/attention (overshoot)
curve: Curves.easeOutBack
```

### Performance

- Keep particle counts reasonable (25-50 for sparkles, 30-50 for confetti)
- Limit stacked effects to 2-3 overlays
- Use `const` widgets where possible
- Cache expensive calculations in TimeConsumer

### Frame Calculations

```dart
// Convert seconds to frames
int secondsToFrames(double seconds, int fps) => (seconds * fps).round();

// Convert frames to seconds
double framesToSeconds(int frames, int fps) => frames / fps;

// Example: 3 seconds at 30fps = 90 frames
final duration = secondsToFrames(3.0, 30); // 90
```

---

## Encoding Settings

```dart
EncodingConfig(
  quality: RenderQuality.high,     // low, medium, high, lossless
  frameFormat: FrameFormat.png,    // png, rawRgba
  crfOverride: 18,                 // Optional CRF override (0-51)
  presetOverride: 'slow',          // Optional FFmpeg preset
  debugFrameOutputPath: 'tmp/frames',
  keepDebugFrames: true,
)
```

---

## Import Statement

Always use this import to access the full declarative API:

```dart
import 'package:fluvie/declarative.dart';
```

This provides access to all widgets: `Video`, `Scene`, `AnimatedProp`, `PropAnimation`, `VCenter`, `VPositioned`, `VColumn`, `VRow`, `LayerStack`, `Layer`, `TimeConsumer`, `AnimatedText`, `TypewriterText`, `CounterText`, `StatCard`, `PolaroidFrame`, `FloatingElement`, `KenBurnsImage`, `EmbeddedVideo`, `ParticleEffect`, `EffectOverlay`, `Background`, `SceneTransition`, `AudioTrack`, `AudioSource`, all templates, and more.
