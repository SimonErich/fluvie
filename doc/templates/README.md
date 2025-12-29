# Templates

Fluvie provides pre-built "Wrapped-style" templates for common video composition patterns. Templates are customizable scene compositions with standardized data contracts for consistent usage.

## Overview

| Category | Description | Use Case |
|----------|-------------|----------|
| [Intro](intro-templates.md) | Opening/identity scenes | Year intro, brand reveals |
| [Ranking](ranking-templates.md) | List/top-N displays | Top songs, favorites |
| [DataViz](data-viz-templates.md) | Data visualization | Statistics, metrics |
| [Collage](collage-templates.md) | Photo arrangements | Photo grids, galleries |
| [Thematic](thematic-templates.md) | Mood/vibe scenes | Lo-fi, retro, glitch |
| [Conclusion](conclusion-templates.md) | Ending/summary scenes | Wrap-up, share CTA |

---

## Quick Start

### Using a Template

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [
    // Create template and convert to Scene
    TheNeonGate(
      data: IntroData(
        title: 'Your 2024',
        subtitle: 'Wrapped',
        year: 2024,
      ),
    ).toScene(),

    // Add more scenes
    StackClimb(
      data: RankingData(
        title: 'Top Songs',
        items: [
          RankingItem(rank: 1, label: 'Song One'),
          RankingItem(rank: 2, label: 'Song Two'),
          RankingItem(rank: 3, label: 'Song Three'),
        ],
      ),
    ).toScene(),
  ],
)
```

### With Transitions

```dart
TheNeonGate(data: introData)
  .toSceneWithCrossFade(fadeDuration: 20)

StackClimb(data: rankingData)
  .toSceneWithSlide(direction: TransitionSlideDirection.left)
```

---

## Template Architecture

### WrappedTemplate Base Class

All templates extend `WrappedTemplate`:

```dart
abstract class WrappedTemplate extends StatelessWidget {
  final TemplateData data;       // Content data
  final TemplateTheme? theme;    // Visual styling
  final TemplateTiming? timing;  // Animation timing

  int get recommendedLength;     // Suggested scene length
  TemplateCategory get category; // Template category
  String get description;        // Template description

  Scene toScene();               // Convert to Scene
  List<Scene> toScenes();        // Convert to multiple Scenes
}
```

### Data Types

Each template category uses specific data types:

| Category | Data Type | Key Fields |
|----------|-----------|------------|
| Intro | `IntroData` | `title`, `subtitle`, `year`, `logoPath` |
| Ranking | `RankingData` | `items`, `title` |
| DataViz | `DataVizData` | `metrics`, `title` |
| Collage | `CollageData` | `images`, `captions` |
| Thematic | `ThematicData` | `text`, `images`, `theme` |
| Conclusion | `SummaryData` | `stats`, `message`, `highlights` |

---

## Data Types Reference

### IntroData

```dart
IntroData(
  title: 'Your 2024',           // Required
  subtitle: 'Wrapped',          // Optional
  year: 2024,                   // Optional
  logoPath: 'assets/logo.png',  // Optional
  userName: 'John',             // Optional
  profileImagePath: 'assets/profile.jpg',  // Optional
)
```

### RankingData

```dart
RankingData(
  title: 'Top Artists',
  subtitle: 'This Year',
  items: [
    RankingItem(
      rank: 1,
      label: 'Artist Name',
      subtitle: '234 hours',
      imagePath: 'assets/artist1.jpg',
      value: 234,
      metadata: {'streams': 5000},
    ),
    RankingItem(rank: 2, label: 'Another Artist'),
    RankingItem(rank: 3, label: 'Third Artist'),
  ],
  isTopList: true,
)
```

### DataVizData

```dart
DataVizData(
  title: 'Your Stats',
  subtitle: 'In Numbers',
  metrics: [
    MetricData(label: 'Hours', value: 1234, unit: 'hrs'),
    MetricData.percentage(label: 'Growth', value: 45),
    MetricData.minutes(label: 'Daily Average', minutes: 120),
    MetricData.count(label: 'Songs', count: 5678),
  ],
  maxValue: 2000,
)
```

### CollageData

```dart
CollageData(
  title: 'Your Moments',
  subtitle: '2024 Gallery',
  images: [
    'assets/photo1.jpg',
    'assets/photo2.jpg',
    'assets/photo3.jpg',
  ],
  captions: ['Beach Day', 'Mountains', 'City'],
  featuredIndex: 0,
  layout: TemplateCollageLayout.grid,
)
```

### ThematicData

```dart
ThematicData(
  text: 'Your Music Journey',
  title: 'The Vibe',
  subtitle: '2024 Edition',
  images: ['assets/mood1.jpg', 'assets/mood2.jpg'],
  statValue: '1,234',
  statLabel: 'hours',
  theme: 'lofi',
  accentColor: Colors.purple,
)
```

### SummaryData

```dart
SummaryData(
  title: 'That\'s a Wrap!',
  subtitle: 'See You Next Year',
  name: 'John',
  year: 2024,
  stats: {
    'Hours': '1,234',
    'Songs': '5,678',
    'Artists': '234',
  },
  highlights: [
    HighlightItem(title: 'Top Fan', description: 'Top 1% of listeners'),
    HighlightItem(title: 'Genre Explorer', description: '12 genres'),
  ],
  message: 'Thanks for an amazing year!',
  ctaText: 'Share Your Wrapped',
  shareUrl: 'https://example.com/share',
)
```

---

## Theming

### TemplateTheme

Customize visual appearance:

```dart
TheNeonGate(
  data: introData,
  theme: TemplateTheme(
    primaryColor: Colors.cyan,
    secondaryColor: Colors.pink,
    backgroundColor: Colors.black,
    textColor: Colors.white,
    accentColor: Colors.purple,
  ),
)
```

### Built-in Themes

```dart
// Neon/cyberpunk style
theme: TemplateTheme.neon

// Spotify-inspired
theme: TemplateTheme.spotify

// Clean minimal
theme: TemplateTheme.minimal

// Warm sunset colors
theme: TemplateTheme.sunset

// Cool ocean blues
theme: TemplateTheme.ocean
```

---

## Timing

### TemplateTiming

Customize animation timing:

```dart
TheNeonGate(
  data: introData,
  timing: TemplateTiming(
    entryDelay: 0,        // Frames before first element
    entryDuration: 30,    // Entry animation duration
    staggerDelay: 10,     // Delay between elements
    holdDuration: 60,     // How long to hold at full
    exitDuration: 20,     // Exit animation duration
  ),
)
```

### Built-in Timings

```dart
// Standard pacing
timing: TemplateTiming.standard

// Slower, more dramatic
timing: TemplateTiming.dramatic

// Faster, snappier
timing: TemplateTiming.snappy

// Very quick
timing: TemplateTiming.quick
```

---

## Converting to Scenes

### Basic Conversion

```dart
// Default scene length
template.toScene()

// Custom length
template.toScene(durationInFrames: 200)

// With transitions
template.toScene(
  durationInFrames: 180,
  transitionIn: SceneTransition.crossFade(durationInFrames: 20),
  transitionOut: SceneTransition.slideLeft(durationInFrames: 15),
)
```

### Convenience Methods

```dart
// Cross-fade both directions
template.toSceneWithCrossFade(fadeDuration: 20)

// Slide transition
template.toSceneWithSlide(
  direction: TransitionSlideDirection.left,
  slideDuration: 25,
)
```

### Multiple Scenes

Some templates generate multiple scenes:

```dart
// Get all scenes from a template
final scenes = complexTemplate.toScenes();

Video(
  scenes: [
    ...introTemplate.toScenes(),
    ...rankingTemplate.toScenes(),
    ...conclusionTemplate.toScenes(),
  ],
)
```

---

## Complete Example

```dart
final introData = IntroData(
  title: 'Your 2024',
  subtitle: 'Wrapped',
  year: 2024,
);

final rankingData = RankingData(
  title: 'Top 5 Songs',
  items: [
    RankingItem(rank: 1, label: 'Song One', imagePath: 'assets/song1.jpg'),
    RankingItem(rank: 2, label: 'Song Two', imagePath: 'assets/song2.jpg'),
    RankingItem(rank: 3, label: 'Song Three', imagePath: 'assets/song3.jpg'),
    RankingItem(rank: 4, label: 'Song Four', imagePath: 'assets/song4.jpg'),
    RankingItem(rank: 5, label: 'Song Five', imagePath: 'assets/song5.jpg'),
  ],
);

final summaryData = SummaryData(
  title: 'That\'s a Wrap!',
  stats: {
    'Hours': '1,234',
    'Songs': '5,678',
  },
  message: 'See you in 2025!',
);

Video(
  fps: 30,
  width: 1080,
  height: 1920,
  backgroundMusicAsset: 'assets/music.mp3',
  scenes: [
    TheNeonGate(
      data: introData,
      theme: TemplateTheme.neon,
    ).toSceneWithCrossFade(),

    StackClimb(
      data: rankingData,
      theme: TemplateTheme.spotify,
    ).toSceneWithSlide(direction: TransitionSlideDirection.left),

    TheSummaryPoster(
      data: summaryData,
    ).toSceneWithCrossFade(),
  ],
)
```

---

## Related

- [Using Templates](using-templates.md) - Detailed usage guide
- [Scene](../widgets/core/scene.md) - Scene widget
- [Video](../widgets/core/video.md) - Video composition
- [SceneTransition](../effects/transitions.md) - Scene transitions
