# Fluvie Templates

Templates are pre-built, customizable scene compositions for creating Spotify Wrapped-style video content. They encapsulate complex animations, layouts, and timing into reusable components.

## Overview

Fluvie includes 30 templates across 6 categories:

| Category | Templates | Purpose |
|----------|-----------|---------|
| **Intro** | 5 | Opening sequences and identity reveals |
| **Ranking** | 5 | Top lists and winner reveals |
| **Data Viz** | 5 | Stats and metrics displays |
| **Collage** | 5 | Multi-image layouts |
| **Thematic** | 5 | Mood and aesthetic experiences |
| **Conclusion** | 5 | Endings and farewell sequences |

## Quick Start

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [
    // Use templates directly as scenes
    TheNeonGate(
      data: IntroData(
        title: 'Your 2024',
        subtitle: 'Wrapped',
        year: 2024,
      ),
    ).toScene(),

    StackClimb(
      data: RankingData(
        title: 'Top Artists',
        items: [
          RankingItem(rank: 1, title: 'Artist One', subtitle: '500 plays'),
          RankingItem(rank: 2, title: 'Artist Two', subtitle: '420 plays'),
          RankingItem(rank: 3, title: 'Artist Three', subtitle: '380 plays'),
        ],
      ),
    ).toScene(),

    ParticleFarewell(
      data: SummaryData(
        message: 'See you next year!',
        year: 2024,
      ),
    ).toScene(),
  ],
)
```

## Template Categories

### Intro Templates

Opening sequences that establish identity and set the mood.

| Template | Description |
|----------|-------------|
| `TheNeonGate` | Neon-lit portal with dramatic text reveal |
| `DigitalMirror` | Reflective glass effect with mirrored animations |
| `TheMixtape` | Cassette tape-inspired retro intro |
| `VortexTitle` | Swirling vortex with centered title |
| `NoiseID` | Static noise effect with identity reveal |

### Ranking Templates

Display top lists with engaging animations.

| Template | Description |
|----------|-------------|
| `StackClimb` | Items stack and climb upward |
| `SlotMachine` | Slot machine-style rolling reveal |
| `TheSpotlight` | Items step into a spotlight |
| `PerspectiveLadder` | 3D perspective ladder effect |
| `FloatingPolaroids` | Polaroid photos floating in space |

### Data Visualization Templates

Present statistics and metrics with visual impact.

| Template | Description |
|----------|-------------|
| `OrbitalMetrics` | Orbital rings displaying data points |
| `TheGrowthTree` | Tree growing with data branches |
| `LiquidMinutes` | Liquid fill representing time |
| `FrequencyGlow` | Audio frequency visualization |
| `BinaryRain` | Matrix-style binary data rain |

### Collage Templates

Multi-image layouts for showcasing collections.

| Template | Description |
|----------|-------------|
| `TheGridShuffle` | Grid of images that shuffle and reveal |
| `SplitPersonality` | Split-screen image comparison |
| `MosaicReveal` | Mosaic tiles revealing an image |
| `BentoRecap` | Bento box grid layout |
| `TriptychScroll` | Three-panel horizontal scroll |

### Thematic Templates

Mood-setting visual experiences.

| Template | Description |
|----------|-------------|
| `LofiWindow` | Lofi aesthetic with window scene |
| `GlitchReality` | Digital glitch effects |
| `RetroPostcard` | Vintage postcard aesthetic |
| `Kaleidoscope` | Kaleidoscopic pattern generation |
| `MinimalistBeat` | Minimal design with beat sync |

### Conclusion Templates

Endings that leave a lasting impression.

| Template | Description |
|----------|-------------|
| `ParticleFarewell` | Particle explosion farewell |
| `TheSignature` | Signature-style ending |
| `TheSummaryPoster` | Summary poster layout |
| `TheInfinityLoop` | Infinity symbol animation |
| `WrappedReceipt` | Receipt-style summary |

## Data Models

Each template category has a corresponding data model:

```dart
// Intro templates
IntroData(
  title: 'Your 2024',
  subtitle: 'Wrapped',
  year: 2024,
  username: 'optional_user',
)

// Ranking templates
RankingData(
  title: 'Top Artists',
  items: [
    RankingItem(rank: 1, title: 'Name', subtitle: 'Details', imageUrl: 'url'),
  ],
)

// Data viz templates
MetricsData(
  title: 'Your Stats',
  metrics: [
    Metric(label: 'Hours', value: 1234),
    Metric(label: 'Songs', value: 5678),
  ],
)

// Collage templates
CollageData(
  images: ['url1', 'url2', 'url3'],
  title: 'Your Moments',
)

// Thematic templates
ThematicData(
  mood: 'chill',
  primaryColor: Colors.purple,
)

// Conclusion templates
SummaryData(
  message: 'Until next time!',
  year: 2024,
  stats: {'songs': 1000, 'artists': 50},
)
```

## Customization

### Theming

All templates support theme customization:

```dart
TheNeonGate(
  data: introData,
  theme: TemplateTheme(
    primaryColor: Colors.purple,
    secondaryColor: Colors.pink,
    backgroundColor: Colors.black,
    textStyle: TextStyle(
      fontFamily: 'CustomFont',
      color: Colors.white,
    ),
    accentGradient: LinearGradient(
      colors: [Colors.purple, Colors.pink],
    ),
  ),
)
```

### Timing

Customize animation timing:

```dart
TheNeonGate(
  data: introData,
  timing: TemplateTiming(
    entryDuration: 30,  // frames
    holdDuration: 60,
    exitDuration: 30,
    staggerDelay: 5,
  ),
)
```

### Scene Options

Use helper methods for common scene configurations:

```dart
// With cross-fade transitions
myTemplate.toSceneWithCrossFade(fadeDuration: 15)

// With slide transitions
myTemplate.toSceneWithSlide(
  direction: TransitionSlideDirection.left,
  slideDuration: 20,
)

// Custom scene configuration
myTemplate.toScene(
  durationInFrames: 150,  // override recommended length
  fadeInFrames: 10,
  fadeOutFrames: 10,
  transitionIn: SceneTransition.crossFade(durationInFrames: 15),
)
```

## Creating Custom Templates

### Basic Template Structure

```dart
import 'package:fluvie/declarative.dart';

class MyCustomTemplate extends WrappedTemplate with TemplateAnimationMixin {
  const MyCustomTemplate({
    super.key,
    required super.data,
    super.theme,
    super.timing,
  });

  @override
  int get recommendedLength => 120;  // 4 seconds at 30fps

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description => 'My custom intro template';

  @override
  Widget build(BuildContext context) {
    final introData = data as IntroData;
    final colors = effectiveTheme;
    final timing = effectiveTiming;

    return TimeConsumer(
      builder: (context, frame, _) {
        final entryProgress = calculateEntryProgress(
          frame,
          0,
          timing.entryDuration,
        );

        return Container(
          color: colors.backgroundColor,
          child: Center(
            child: Opacity(
              opacity: entryProgress,
              child: Text(
                introData.title,
                style: colors.textStyle,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### Using Animation Helpers

The `TemplateAnimationMixin` provides helper methods:

```dart
// Entry animation (0 to 1)
final entryProgress = calculateEntryProgress(
  frame,      // current frame
  startFrame, // when animation starts
  duration,   // animation duration in frames
  Curves.easeOutCubic,  // optional curve
);

// Exit animation (0 to 1)
final exitProgress = calculateExitProgress(
  frame,
  exitStart,
  duration,
  Curves.easeInCubic,
);

// Combined opacity
final opacity = calculateOpacity(entryProgress, exitProgress);

// Staggered timing
final elementStart = staggeredStartFrame(baseStart, elementIndex);
```

### Template Data Contract

Create a custom data class:

```dart
class MyTemplateData extends TemplateData {
  final String title;
  final List<String> items;
  final Color? accentColor;

  const MyTemplateData({
    required this.title,
    required this.items,
    this.accentColor,
  });
}
```

## Best Practices

1. **Use recommended lengths**: Each template has a `recommendedLength` optimized for its animations
2. **Respect timing**: Use `effectiveTiming` to ensure consistent animation feel
3. **Theme consistency**: Use `effectiveTheme` to respect user customizations
4. **Test transitions**: Verify your templates work well with various scene transitions
5. **Document requirements**: Specify required assets in `requiredAssets` getter

## Performance Tips

- Templates use `RepaintBoundary` automatically for efficient rendering
- Use `TimeConsumer` for frame-based animations
- Prefer `Fade` widgets over `Opacity` with `saveLayer` artifacts
- Keep particle counts reasonable for mobile performance
